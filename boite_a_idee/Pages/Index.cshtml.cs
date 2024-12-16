using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySql.Data.MySqlClient;
using System;

namespace pBullBoiteaidee.Pages
{
    public class IndexModel : PageModel
    {
        private static readonly MySqlConnection conn = new(GetConnectionString());

        private static string GetConnectionString()
        {
            return "server=db;port=3306;user=root;password=root;database=boiteaidee;";
        }

        public void OnGet()
        {
            EnsureDatabaseExists();
            Tester();
        }

        public static void EnsureDatabaseExists()
        {
            try
            {
                using (var connection = new MySqlConnection("server=db;port=3306;user=root;password=root;"))
                {
                    connection.Open();
                    var cmd = connection.CreateCommand();
                    cmd.CommandText = "CREATE DATABASE IF NOT EXISTS boiteaidee;";
                    cmd.ExecuteNonQuery();

                    // S'assurer que la connexion utilise la nouvelle base de données
                    cmd.Connection.ChangeDatabase("boiteaidee");

                    // Création de la table t_idee si elle n'existe pas déjà
                    cmd.CommandText = @"
                    CREATE TABLE IF NOT EXISTS t_idee (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        idtext TEXT NOT NULL
                    );";
                    cmd.ExecuteNonQuery();
                }
            }
            catch (MySqlException e)
            {
                Console.WriteLine($"Erreur lors de la création de la base de données ou de la table : {e.Message}");
            }
        }

        public static string Tester()
        {
            try
            {
                conn.ConnectionString = GetConnectionString() + "database=boiteaidee;";
                conn.Open();
                return "la db fonctionne";
            }
            catch (MySqlException e)
            {
                return $"Erreur lors de la connexion : {e.Message}";
            }
            finally
            {
                conn.Close();
            }
        }

        public static int TimerSeconds = 0;

        public string DisplayTime => $"{TimerSeconds / 60:D2}:{TimerSeconds % 60:D2}";

        public IActionResult OnPostIncreaseTime()
        {
            TimerSeconds++;
            return RedirectToPage();
        }

        public IActionResult OnPostDecreaseTime()
        {
            TimerSeconds = Math.Max(0, TimerSeconds - 1);
            return RedirectToPage();
        }
    }
}
