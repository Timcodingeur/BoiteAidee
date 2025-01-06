using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySql.Data.MySqlClient;
using System;

namespace pBullBoiteaidee.Pages
{
    public class IndexModel : PageModel
    {
        public static MySqlConnection conn;
        public static string ConnectionString;

        static IndexModel()
        {
            // Configuration de la chaîne de connexion pour hors conteneur
            ConnectionString = GetLocalConnectionString();
            conn = new MySqlConnection(ConnectionString);

            // Si vous voulez utiliser une connexion en conteneur, commentez la ligne ci-dessus et décommentez ci-dessous.
            // ConnectionString = GetContainerConnectionString();
            // conn = new MySqlConnection(ConnectionString);
        }

        private static string GetLocalConnectionString()
        {
            // Configuration pour une exécution hors conteneur
            return "server=localhost;port=6033;user=root;password=root;";
        }

        private static string GetContainerConnectionString()
        {
            // Configuration pour une exécution dans un conteneur Docker
            return "server=db;port=3306;user=root;password=root;";
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
                using (var connection = new MySqlConnection(ConnectionString))
                {
                    connection.Open();
                    var cmd = connection.CreateCommand();

                    // Création de la base de données si elle n'existe pas
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
            catch (Exception e)
            {
                Console.WriteLine($"Erreur inattendue : {e.Message}");
            }
        }

        public static string Tester()
        {
            try
            {
                conn.ConnectionString = ConnectionString;
                conn.Open();
                return "La base de données fonctionne correctement.";
            }
            catch (MySqlException e)
            {
                return $"Erreur lors de la connexion à la base de données : {e.Message}";
            }
            catch (Exception e)
            {
                return $"Erreur inattendue lors de la connexion : {e.Message}";
            }
            finally
            {
                conn.Close();
            }
        }

        // Timer pour illustration (inchangé)
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
