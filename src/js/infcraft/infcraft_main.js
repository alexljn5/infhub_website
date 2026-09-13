const ircButton = document.getElementById('ircButton');

if (ircButton) {
    ircButton.addEventListener('click', function () {
        window.location.href = 'https://irc.infhub.org';
    });
}