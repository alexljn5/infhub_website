// Handle server box clicks
const serverBoxes = document.querySelectorAll('.serverBox');
let clickCounts = {};

serverBoxes.forEach(box => {
    const serverId = box.id;
    clickCounts[serverId] = 0;

    // Click event
    box.addEventListener('click', function () {
        clickCounts[serverId]++;
        console.log(`${serverId} clicked! Count: ${clickCounts[serverId]}`);

        // Add click animation
        box.classList.add('clicked');
        setTimeout(() => {
            box.classList.remove('clicked');
        }, 200);

        // Redirect based on server ID
        if (serverId === 'infcraftBox') {
            window.location.href = 'php/pages/infcraft.php';
        }
    });

    // Hover effect
    box.addEventListener('mouseenter', function () {
        this.style.transform = 'scale(1.1)';
    });

    box.addEventListener('mouseleave', function () {
        this.style.transform = 'scale(1)';
    });
});