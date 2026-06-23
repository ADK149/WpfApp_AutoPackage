using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace WpfApp_AutoPackage
{
    public partial class MainWindow : Window
    {
        public new string Content { get; set; } = "Hello, World!";
        public string Version { get; set; } = "Version:1.0.1";
        public MainWindow()
        {
            InitializeComponent();
            ContentLable.Content = Content;
            VersionLable.Content = Version;
        }
    }
}