using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySql.Data.MySqlClient;
using System;

namespace pBullBoiteaidee.Pages
{
    public class notetimeModel : PageModel
    {
        [BindProperty]
        public string IdeeText { get; set; }

        public void OnGet()
        {
        }

        public int TimerSecond = IndexModel.TimerSeconds;
        public string DisplayTimes => $"{TimerSecond / 60:D2}:{TimerSecond % 60:D2}";

        public IActionResult OnPostValide()
        {
            string fileName = "info.txt";

            using (StreamWriter writer = new StreamWriter(fileName, true))
            {
                writer.WriteLine(IdeeText);
            }

            using (var conn = new MySqlConnection(GetConnectionString()))
            {
                conn.Open();
                using (var cmd = new MySqlCommand("INSERT INTO t_idee (idtext) VALUES (@idee);", conn))
                {
                    cmd.Parameters.AddWithValue("@idee", IdeeText);
                    cmd.ExecuteNonQuery();
                }
            }

            return RedirectToPage();
        }

        public static string GetConnectionString()
        {
            return "server=localhost;port=6033;user=root;password=root;database=boiteaidee;";
        }
    }
}
