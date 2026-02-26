const tabButtons = document.querySelectorAll('.tabButton');
const forms = document.querySelectorAll('.form');

tabButtons.forEach(button => {
    button.addEventListener('click', function () {
        const tabName = this.getAttribute('data-tab');

        // Remove active class from all buttons and forms
        tabButtons.forEach(btn => btn.classList.remove('active'));
        forms.forEach(form => form.classList.remove('active'));

        // Add active class to clicked button and corresponding form
        this.classList.add('active');
        document.getElementById(tabName + 'Form').classList.add('active');
    });
});

// Header dropdown toggle
const loginToggleBtn = document.getElementById('loginToggleBtn');
const headerDropdown = document.getElementById('headerAuthDropdown');

if (loginToggleBtn && headerDropdown) {
    loginToggleBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        headerDropdown.classList.toggle('open');
        const expanded = headerDropdown.classList.contains('open');
        headerDropdown.setAttribute('aria-hidden', expanded ? 'false' : 'true');
    });

    // Close when clicking outside
    document.addEventListener('click', function (e) {
        if (headerDropdown.classList.contains('open') && !headerDropdown.contains(e.target) && e.target !== loginToggleBtn) {
            headerDropdown.classList.remove('open');
            headerDropdown.setAttribute('aria-hidden', 'true');
        }
    });
}