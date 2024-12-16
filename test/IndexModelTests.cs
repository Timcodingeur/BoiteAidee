using Microsoft.VisualStudio.TestTools.UnitTesting;
using pBullBoiteaidee.Pages;
using System.IO;
using MySql.Data.MySqlClient;


namespace pBullBoiteaidee.Tests
{
    [TestClass]
    public class IndexModelTests
    {
        [TestMethod]
        public void TestEnsureDatabaseExists()
        {
            // Act
            IndexModel.EnsureDatabaseExists();

            // Since we can't directly check the database, we can assume no exceptions means success
            Assert.IsTrue(true);
        }

        [TestMethod]
        public void TestTesterConnectionSuccess()
        {
            // Act
            var result = IndexModel.Tester();

            // Assert
            Assert.AreEqual("la db fonctionne", result);
        }

        [TestMethod]
        public void TestIncreaseTime()
        {
            // Arrange
            var indexModel = new IndexModel();

            // Act
            indexModel.OnPostIncreaseTime();

            // Assert
            Assert.AreEqual(1, IndexModel.TimerSeconds);
        }

        [TestMethod]
        public void TestDecreaseTime()
        {
            // Arrange
            var indexModel = new IndexModel();
            IndexModel.TimerSeconds = 1;

            // Act
            indexModel.OnPostDecreaseTime();

            // Assert
            Assert.AreEqual(0, IndexModel.TimerSeconds);
        }
    }
}
