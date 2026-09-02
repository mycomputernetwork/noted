package app.noted

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts.StartActivityForResult
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import app.noted.ui.BoardScreen
import app.noted.ui.BoardViewModel
import app.noted.ui.EditorScreen
import app.noted.ui.FolderManagerScreen
import app.noted.ui.SignInScreen
import app.noted.ui.theme.NotedTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            NotedTheme {
                val nav = rememberNavController()
                val vm: BoardViewModel = viewModel()
                val signedIn by vm.signedIn.collectAsState()
                val signInError by vm.signInError.collectAsState()
                val signInInProgress by vm.signInInProgress.collectAsState()

                // The browser hands the authorization code back here.
                val signIn = rememberLauncherForActivityResult(StartActivityForResult()) { result ->
                    result.data?.let(vm::completeSignIn) ?: vm.cancelSignIn()
                }

                // Ending auth's session is best-effort: the tokens go either way.
                val signOut = rememberLauncherForActivityResult(StartActivityForResult()) {}

                LaunchedEffect(signedIn) {
                    val destination = if (signedIn) "board" else "signin"
                    if (nav.currentDestination?.route != destination) {
                        nav.navigate(destination) { popUpTo(0) }
                    }
                }

                NavHost(
                    navController = nav,
                    startDestination = if (signedIn) "board" else "signin",
                    enterTransition = { EnterTransition.None },
                    exitTransition = { ExitTransition.None },
                    popEnterTransition = { EnterTransition.None },
                    popExitTransition = { ExitTransition.None },
                ) {
                    composable("signin") {
                        SignInScreen(error = signInError, signingIn = signInInProgress) { signIn.launch(vm.signInIntent()) }
                    }
                    composable("board") {
                        BoardScreen(
                            vm = vm,
                            onOpenNote = { nav.navigate("note/$it") },
                            onNewNote = { nav.navigate("note/${vm.repo.newNoteId()}") },
                            onSignOut = {
                                vm.signOutIntent()?.let(signOut::launch)
                                vm.signOut()
                            },
                            onManageFolders = { nav.navigate("folders") },
                            onCreateFolder = { nav.navigate("folders/new") },
                        )
                    }
                    composable("folders") {
                        FolderManagerScreen(vm = vm, startCreating = false) { nav.popBackStack() }
                    }
                    composable("folders/new") {
                        FolderManagerScreen(vm = vm, startCreating = true) { nav.popBackStack() }
                    }
                    composable("note/{id}") { entry ->
                        EditorScreen(vm, entry.arguments!!.getString("id")!!) { nav.popBackStack() }
                    }
                }
            }
        }
    }
}
