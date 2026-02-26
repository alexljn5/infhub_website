<header>
    <h1>INFCRAFT</h1>
    <div class="headerControls">
        <button id="loginToggleBtn" class="loginToggle">Login/Register</button>
        <div id="headerAuthDropdown" class="headerAuthDropdown" aria-hidden="true">
            <!-- The form container will be moved here dynamically or duplicated -->
            <div class="formContainer compact" id="headerFormContainer">
                <div class="formTabs">
                    <button class="tabButton active" data-tab="login">Login</button>
                    <button class="tabButton" data-tab="register">Register</button>
                </div>

                <form id="loginForm" class="form active" method="POST" action="">
                    <div class="formGroup">
                        <label for="loginUsername">Username:</label>
                        <input type="text" id="loginUsername" name="username" required>
                    </div>
                    <div class="formGroup">
                        <label for="loginPassword">Password:</label>
                        <input type="password" id="loginPassword" name="password" required>
                    </div>
                    <button type="submit" class="submitBtn">Login</button>
                </form>

                <form id="registerForm" class="form" method="POST" action="">
                    <div class="formGroup">
                        <label for="registerUsername">Username:</label>
                        <input type="text" id="registerUsername" name="username" required>
                    </div>
                    <div class="formGroup">
                        <label for="registerEmail">Email:</label>
                        <input type="email" id="registerEmail" name="email" required>
                    </div>
                    <div class="formGroup">
                        <label for="registerPassword">Password:</label>
                        <input type="password" id="registerPassword" name="password" required>
                    </div>
                    <button type="submit" class="submitBtn">Register</button>
                </form>
            </div>
        </div>
    </div>
</header>