using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySql.Data.MySqlClient;
using System;

namespace pBullBoiteaidee.Pages
{
    public class IndexModel : PageModel
    {
        private static MySqlConnection conn;
        private static string ConnectionString;

        static IndexModel()
        {
            // Configuration dynamique de la chaîne de connexion
            ConnectionString = GetDynamicConnectionString();
            conn = new MySqlConnection(ConnectionString);
        }

        private static string GetDynamicConnectionString()
        {
            string containerConnectionString = "server=db;port=3306;user=root;password=root;database=boiteaidee;";
            if (TestDatabaseConnection(containerConnectionString))
            {
                Console.WriteLine("Connexion réussie à db:3306 (conteneur).");
                return containerConnectionString;
            }
            else
            {
                Console.WriteLine("Échec de la connexion à db:3306 (conteneur).");
            }

            string localConnectionString = "server=localhost;port=6033;user=root;password=root;database=boiteaidee;";
            if (TestDatabaseConnection(localConnectionString))
            {
                Console.WriteLine("Connexion réussie à localhost:6033 (hors conteneur).");
                return localConnectionString;
            }
            else
            {
                Console.WriteLine("Échec de la connexion à localhost:6033 (hors conteneur).");
            }

            throw new Exception("Impossible de se connecter à la base de données. Vérifiez la configuration.");
        }


        private static bool TestDatabaseConnection(string connectionString)
        {
            try
            {
                using var connection = new MySqlConnection(connectionString);
                connection.Open();
                return true; // Connexion réussie
            }
            catch
            {
                return false; // Connexion échouée
            }
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
