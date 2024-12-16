using Microsoft.VisualStudio.TestTools.UnitTesting;
using pBullBoiteaidee.Pages;
using System.IO;
using MySql.Data.MySqlClient;

namespace pBullBoiteaidee.Tests
{
    [TestClass]
    public class notetimeModelTests
    {
        [TestMethod]
        public void TestOnPostValide()
        {
            // Arrange
            var notetimeModel = new notetimeModel();
            notetimeModel.IdeeText = "Test Idee";

            // Check initial count
            int initialCount;
            using (var conn = new MySqlConnection(notetimeModel.GetConnectionString()))
            {
                conn.Open();
                using (var cmd = new MySqlCommand("SELECT COUNT(*) FROM t_idee WHERE idtext = @idee;", conn))
                {
                    cmd.Parameters.AddWithValue("@idee", "Test Idee");
                    initialCount = Convert.ToInt32(cmd.ExecuteScalar());
                }
            }

            // Act
            var result = notetimeModel.OnPostValide();

            // Assert
            Assert.IsNotNull(result);

            // Check if the file is created and contains the expected text
            var fileName = "info.txt";
            Assert.IsTrue(File.Exists(fileName));
            var content = File.ReadAllText(fileName);
            Assert.IsTrue(content.Contains("Test Idee"));

            // Check if the idea is inserted into the database and count has increased by 1
            using (var conn = new MySqlConnection(notetimeModel.GetConnectionString()))
            {
                conn.Open();
                using (var cmd = new MySqlCommand("SELECT COUNT(*) FROM t_idee WHERE idtext = @idee;", conn))
                {
                    cmd.Parameters.AddWithValue("@idee", "Test Idee");
                    var newCount = Convert.ToInt32(cmd.ExecuteScalar());
                    Assert.AreEqual(initialCount + 1, newCount);
                }

                // Clean up the test data
                using (var deleteCmd = new MySqlCommand("DELETE FROM t_idee WHERE idtext = @idee;", conn))
                {
                    deleteCmd.Parameters.AddWithValue("@idee", "Test Idee");
                    deleteCmd.ExecuteNonQuery();
                }
            }
        }
    }
}
