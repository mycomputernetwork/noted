package app.noted

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import app.noted.ui.BoardScreen
import app.noted.ui.BoardViewModel
import app.noted.ui.EditorScreen
import app.noted.ui.theme.NotedTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            NotedTheme {
                val nav = rememberNavController()
                val vm: BoardViewModel = viewModel()
                NavHost(navController = nav, startDestination = "board") {
                    composable("board") {
                        BoardScreen(
                            vm = vm,
                            onOpenNote = { nav.navigate("note/$it") },
                            onNewNote = { nav.navigate("note/${vm.repo.newNoteId()}") },
                        )
                    }
                    composable("note/{id}") { entry ->
                        EditorScreen(vm, entry.arguments!!.getString("id")!!) { nav.popBackStack() }
                    }
                }
            }
        }
    }
}
