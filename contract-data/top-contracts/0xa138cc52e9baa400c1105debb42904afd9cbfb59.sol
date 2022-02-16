
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**

██████╗░░█████╗░░█████╗░████████╗░░░░░██╗░█████╗░░█████╗░██╗░░██╗
██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝░░░░░██║██╔══██╗██╔══██╗██║░██╔╝
██████╦╝██║░░██║██║░░██║░░░██║░░░░░░░░██║███████║██║░░╚═╝█████═╝░
██╔══██╗██║░░██║██║░░██║░░░██║░░░██╗░░██║██╔══██║██║░░██╗██╔═██╗░
██████╦╝╚█████╔╝╚█████╔╝░░░██║░░░╚█████╔╝██║░░██║╚█████╔╝██║░╚██╗
╚═════╝░░╚════╝░░╚════╝░░░░╚═╝░░░░╚════╝░╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝
*/

/// This contract has not been audited. Use at your own risk.

/**
The author generated this text in part with GPT-3, OpenAI’s large-scale language-generation model. 
Upon generating draft language, the author reviewed, edited, and revised the language to their own liking 
and takes ultimate responsibility for the content of this publication.
*/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Base64.sol";

contract bootjack0 is ERC721, ReentrancyGuard, Ownable {
    struct MintInfo {
        uint256 cost;
        uint32 maxSupply;
        uint32 nextTokenId;
    }
    MintInfo mintInfo = MintInfo(0.01 ether, 5000, 1);


    string[] private weapons = [
        "Blaster Pistol",
        "Chainsaw",
        "Deadly Dust",
        "Stone Burner",
        "Shard Dagger",
        "Concussion Bomb",
        "Wide-bore Burner",
        "Cellgun",
        "Small Club",
        "Battle Lance",
        "Vara Lance",
        "Cobra",
        "Wingman",
        "Shock Trooper Rifle",
        "Lasrifle",
        "Jericho 941",
        "Pulse Cannon",
        "Glock 30",
        "Slagger",
        "Walther P99",
        "Heckler Koch MP5A2",
        "Quill Gun",
        "Zorg ZF-1",
        "Sonic Club",
        "Directed Energy Cannon",
        "Barbed Spear",
        "Mangalore CP1",
        "Mangalore AK",
        "M2HB",
        "Mauser M712",
        "Electrical Spear",
        "Lewis Gun",
        "Short Spear",
        "Maula Pistol",
        "MAC-10",
        "Laser Rifle",
        "Pipe",
        "Hatchet",
        "Key Sword",
        "Bad Lancer",
        "Energy Whip",
        "Battle Hammer",
        "Battle Axe",
        "Laser Sword",
        "Battlehammer",
        "Scythe",
        "Halberd Sword",
        "Power Pole",
        "Colt Commando",
        "Flamethrower",
        "Cane Gun",
        "M197 Vulcan",
        "Lightning Rifle",
        "Desert Eagle",
        "Dart Gun",
        "Switch Blade",
        "SW 19",
        "Katana",
        "Plasma Cannon",
        "Squid Gun",
        "2x4",
        "Baseball Bat",
        "Disruptor",
        "Micro Uzi",
        "Automatic Shotguns x2",
        "M16",
        "Phaser",
        "92FS",
        "Tarpel Gun",
        "Fusion Rifle",
        "AMC Auto Mag",
        "Submachine Gun",
        "P226",
        "Combat Bow",
        "Shotgun",
        "Trace Rifle",
        "Pulse Rifle",
        "Machete",
        "Hand Cannon",
        "Derringer",
        "Scout Rifle",
        "Machine Gun",
        "Power Sword",
        "Trident",
        "Grenade Launcher",
        "Sniper Rifle",
        "Blitmap",
        "Two Twenty",
        "Pump Shotgun",
        "Longbow",
        "Frag Grenade",
        "PC-9",
        "Stinger",
        "PS20",
        "Scorpio",
        "M79",
        "Vulcan Minigun",
        "Killer7",
        "Pipe Gun",
        "Stun Baton",
        "Nailgun",
        "Rocket Launcher",
        "Laser Cannon",
        "Crowbar",
        "Molotov Cocktail",
        "Doritos Bag and Zipties"
    ];

    string[] private clothing = [
        "White Tshirt",
        "Hack The Planet TShirt",
        "Bomber Jacket",
        "Armor-Quilted Jacket",
        "Yukata",
        "Ballistic Vest",
        "Polycarbonate Turtleneck",
        "Hybrid Weave Sweater",
        "Thermoset Jacket",
        "Graphene-Weave Jacket",
        "Silk Kimono",
        "Levitation Boots",
        "Gladiator Armor",
        "Dri-Fit Shirt",
        "Anti-Puncture Shirt",
        "Interface Suit",
        "Hordak Bone Armor",
        "Doritos Hoodie",
        "Thermoactive Jacket",
        "Synweave Dress",
        "Duolayer Puffer Vest",
        "Samurai Turtleneck",
        "Surge Jogger",
        "Synweave Yukata",
        "Survival Suit",
        "Synweave Jacket",
        "Gold Silk Vest",
        "Nikon Cloak",
        "Flex Stride Shorts",
        "Isolation Suit",
        "Metal Vent T-shirt",
        "EV Suit",
        "Bio-mimetic Garment",
        "Flight Suit",
        "Neon Orange Puffer Vest",
        "Polycarb Trench Coat",
        "Leather Trench Coat",
        "Fur Coat",
        "White Wool Turtleneck",
        "Tactical Coat",
        "Transparent Trench",
        "Black Leather Overcoat",
        "RunDao Tshirt",
        "Devotion Robes",
        "Leopard Parachute Pants",
        "Leather Moto Jacket",
        "Cat Rose TShirt",
        "Suzuki Moto Jacket",
        "Tactical Vest",
        "Knight Robes",
        "Power Suit",
        "Doritos Polo",
        "Blitmap Tshirt",
        "Patagonia Vest",
        "Hover Suit",
        "Planeswalker Cloak",
        "Terry Cloth Bathrobe",
        "Kevlar Vest",
        "Duct Tape Overcoat",
        "Tie Dye Overalls",
        "Wet Suit",
        "Power Armor",
        "Planeswalker Armor",
        "Ion Suit",
        "Suit of Power",
        "Leather Jacket",
        "Leather Overcoat",
        "Silk Dress",
        "Ice Princess Robes",
        "Plaid Shirt",
        "Morning Coat",
        "Vestments of Faith",
        "Red Hoodie",
        "Squid Suit",
        "Lizard Scale Mail",
        "Dragon Skin Cloak",
        "Denim Overalls",
        "Longcoat",
        "Leather Armor",
        "Military Fatigues",
        "Bunny Suit",
        "Fallen Angel Robes",
        "Black Leather Armor",
        "Fur Lined Cloak",
        "Sorceress Robes",
        "Pleather Pants",
        "Tribal Skirt",
        "Pleather Armor",
        "Leather Vest",
        "Leather Pants",
        "Avant Garde Dress",
        "Ranger's Tunic",
        "Bunny Suit",
        "Knight Armor",
        "Duelist Plate"
    ];

    string[] private vehicle = [
        "Cybertruck",
        "Ornithopter",
        "VTOL",
        "Groundcar",
        "Moto Guzzi 850",
        "ForFour",
        "Combat Tank",
        "Suburban",
        "Civilian",
        "F Series Pickup",
        "Alfa Romeo Spinner",
        "GM TDH 4507",
        "Armadillo Van",
        "Dust Scout",
        "Raider Trike",
        "Audi A4",
        "SAAB 99",
        "KLR 650 Bike",
        "Audi TT",
        "Globefish",
        "Hovercar",
        "Jupiter 8",
        "Jet Squirrel",
        "Cadilac Eldorado",
        "1969 Ford Mustang",
        "Ducati Scrambler 1100",
        "Porsche 912",
        "Ford Granada",
        "Sonic Tank",
        "MB Unimog",
        "Spice Rocket",
        "BMW 2002",
        "Crown Victoria",
        "Cube",
        "Armored Limousine",
        "Sand Crawler",
        "Ford Raptor",
        "MV Agusta F4",
        "Lamborghini Countach",
        "Ferrari F40",
        "Porsche 911 Carrera RS",
        "Volkswagen Beetle",
        "Peugot Spinner",
        "Squidder",
        "Cannondale Roadbike",
        "Scout Flyer",
        "Levtrain",
        "Steel Quads",
        "Spinner",
        "Blitmap Bus",
        "Doritos Delivery Truck",
        "Forklift",
        "RV",
        "Formula Racer",
        "Rally Fighter",
        "Roadster",
        "Blimp",
        "Custom Hot Rod",
        "Big Rig",
        "Aerodyne",
        "Electrola Roadster",
        "Tesla Model 3"
    ];

    string[] private gear = [
        "Tactical Belt",
        "Carbon Fiber Belt",
        "Bandolier of Ammo",
        "Katana Sheath",
        "EpiPen",
        "Mega Today Magazine",
        "Orange Sweatband",
        "Code Bomb",
        "Yellow Sweatband",
        "Green Sweatband",
        "Indigo Sweatband",
        "White Sweatband",
        "Black Sweatband",
        "Destron Gas",
        "Tez Bot Software",
        "Bugout Bag",
        "Case of Jolt Cola",
        "Hard Hat",
        "Lockpicking Kit",
        "Skull Fest Ticket",
        "Gibson Garbage File",
        "Neo Christianist Pamphlets",
        "Havoc Goggles",
        "Bandages",
        "Medical Kit",
        "Hackers Utility Belt",
        "Marauders Bag",
        "Arena Bet Ticket",
        "GM Book of Secrets",
        "Pistol Holster",
        "Rusty Nails",
        "Squid Camo Net",
        "MC Royals Ticket",
        "Running Socks",
        "Traag Knowledge Book",
        "Funnel Web Spider Poison",
        "Crate of Bottled Water",
        "Club 21 VIP Pass",
        "Duct Tape",
        "Archery Quiver",
        "Pink Shirt Book",
        "Red Book",
        "Devil Book",
        "Dragon Book",
        "Polycarb Belt",
        "Safety Glasses",
        "Doritos Clipboard",
        "Advanced Robotics",
        "Yamada Robotics Belt",
        "Black Nail Polish",
        "Runner's Belt",
        "Broken Scissors",
        "Water Bottle Belt",
        "Wire Cutters",
        "Flare Gun",
        "Alien Tech Belt",
        "Bot Wiring",
        "Doritos Windbreaker",
        "Hackers Backpack",
        "Leather Fanny Pack",
        "Hacker Belt",
        "Blitmaps Tote",
        "Patagonia Tech Web"
    ];

    string[] private footwear = [
        "Pegasus",
        "Floatride",
        "UltraBoost",
        "Ghost",
        "Endorphin Pro",
        "Wave Rebellion",
        "ZWorth Air",
        "Air Max 94",
        "Deviate Nitro",
        "One Carbon",
        "Avatar Boot",
        "Meta Speed",
        "Rincon 3",
        "Adipure",
        "Five Fingers",
        "Fuel Cell",
        "Inline Skates",
        "Triumph",
        "Speedcross",
        "Wave Elixir",
        "Air Rift",
        "Ultraride",
        "Ultra Kiawe",
        "Charge",
        "Sprint",
        "Pulse",
        "Cadence",
        "Rocket Boots",
        "Skateboard Shoes",
        "Bionic Boots",
        "Cortana 2",
        "Plasma Boots",
        "Momentum",
        "Max 97",
        "Ghost Racer",
        "MZ-84",
        "Heman Boots",
        "Free Runner",
        "Skytop II",
        "Marathon",
        "Max 180",
        "Cloud Runner",
        "Leather Boots",
        "Pure Cadence",
        "GL6000",
        "Presto",
        "Crosstown",
        "TX-3",
        "Cephpod Runner",
        "Tactical Boots",
        "Zoom JST",
        "Street Glide",
        "Super Man",
        "Cybershoes",
        "Skytop II",
        "Cruzer",
        "Proto Boot",
        "Air Force 1",
        "Wave Rider",
        "Max 95",
        "Citizen",
        "Waffle Trainer",
        "El Tigre",
        "ZX 500",
        "Hover Boots",
        "Power Boots",
        "Boost Boots",
        "Huarache",
        "Gravity",
        "Bermuda",
        "Bot Boots",
        "Slides",
        "Furlined Tactical Boots",
        "Mil Spec Boot",
        "Alien Tek Runer",
        "Skull Sneaker",
        "SL 72",
        "Cortez",
        "Air Flow",
        "Easy Rider",
        "Allbirds",
        "Velcro Runners",
        "Custom Doritos Hightops",
        "Blitmap Boots"
    ];

    string[] private hardware = [
        "Tablet",
        "Code Book",
        "Worm Program USB",
        "EM Pulse Generator",
        "Laptop",
        "Raspberry Pi 3",
        "Neural Link",
        "Reality Machine",
        "Coat Check Keycard",
        "Bag of Marbles",
        "ST88 X",
        "Laser Tripwire",
        "Miniature EMP Generator",
        "Retinal Scanner",
        "Hallusomnetic Chair",
        "USBArmory",
        "LinkCore Prototype",
        "OutKast CD",
        "Zotax GTX 1050 Ti Mini",
        "Wireless Headphones",
        "Mechanical Keyboard",
        "Bash Bunny",
        "Wrench",
        "Ubertooth 1",
        "Wifi Pineapple",
        "Zigbee",
        "Gaming Computer",
        "Rubber Ducky",
        "Voice Changer",
        "Long-Range Antenna",
        "KeyLogger",
        "Da Vinci Virus Drive",
        "GPS Tracking Device",
        "Proxmark 3",
        "Fitbit",
        "Blackberry",
        "Nokia Brick",
        "Motorola Razr",
        "Mind Control Device",
        "Satelite Orbital Laser",
        "Cryogenic Containment Unit",
        "Hardware Wallet",
        "ROM Module",
        "EMP Shield",
        "Mini Drone",
        "RFID Duplicator",
        "Blitmap Decoder",
        "Smartphone",
        "Doritos HQ Key Card"
    ];

    string[] private loot = [
        "Gold Coins",
        "Silver Coins",
        "Synthetic Diamonds",
        "Platinum Bars",
        "Titanium Orbs",
        "Opalfire Jewels",
        "Fire Jewels",
        "Stolen Credits",
        "Tanzanite Stones",
        "Taffeite Stones",
        "Processing Chips",
        "Black Opals",
        "Benitoite Stones",
        "Musgravite Stones",
        "$RunFree Tokens",
        "Painite Stones",
        "Hagal Stones",
        "Star Jewels",
        "Royals Championship Ring",
        "Painite Stones",
        "Infinity Stones",
        "Bot Chips",
        "Tek Fuel",
        "Skull Key",
        "Race Medals",
        "Cool Ranch Doritos",
        "Special Candy",
        "Rich Stones",
        "Musgravite Gemstones"
    ];

    string[] private locations = [
        "Sector 1",
        "Sector 2",
        "Sector 3",
        "Sector 4",
        "Sector 5",
        "Sector 6",
        "Sector 7",
        "Sector 8",
        "Sector 9",
        "Sector 10",
        "Sector 11",
        "Sector 12",
        "Alpha District",
        "Beta District",
        "Gamma District",
        "Delta District",
        "Zeta District"
    ];

    string[] private destinations = [
        "Arts District",
        "Dark Woods",
        "Lost Sector",
        "Cabled Underground",
        "Crispr Lab",
        "Mega City Slums",
        "The Lotus Temple",
        "Wreckers Row",
        "Nightlife District",
        "The Outskirts",
        "The Squid Palace",
        "The Hub",
        "The Walls",
        "Etown",
        "The Cliffs",
        "Mega City Cafe",
        "The Somnetic Pagoda",
        "The Lucky Club",
        "Alien Ninja Clan HQ",
        "Nekogumi HQ",
        "The Neo-Bellagio",
        "The Tech District",
        "Blue Side",
        "Interstellar Port",
        "The Flying Snark",
        "Betty Jean's Titty Bar",
        "Red Eye Syndicate Layer",
        "Sand Volley Ball Arena",
        "Mega City Radio Station",
        "Skull District",
        "The Ice Cream Factory",
        "Buseo Boxing Gym",
        "Club 21",
        "The Tracks",
        "The Bitpacking District",
        "ZK Uptown",
        "MC Ghetto",
        "Quad Stream River District",
        "Chain Alleys",
        "Yamada Robotics HQ",
        "Blitcorp HQ",
        "Alien Station Z",
        "Mummy Cult House",
        "Millennium Archives",
        "Mega Mobile HQ",
        "Cascadia Marketplace",
        "Tezark Industries HQ",
        "Dorito Gang District",
        "Mega City Hospital",
        "Skull Base 0",
        "The Sewers",
        "Downtown",
        "The Neo Christianist Temple",
        "The Surgeon's Lab",
        "Armory  Annex",
        "Megaplex Grid",
        "Ybur",
        "Doritos Mega City HQ",
        "Bot Town",
        "Hal's Hardware",
        "Cool Ranch Club",
        "Ed's Laundry Emporium",
        "Temple of Gold",
        "Hansen Hills",
        "The Lighthouse",
        "Mega City Super Max",
        "Mega City Clink"
    ];

    string[] private contraband = [
        "Awareness Spectrum",
        "Elacca ",
        "Rossak",
        "Sapho",
        "Spice Melange",
        "EPO",
        "Stolen Black Cherry Tobacco",
        "HGH",
        "Diuretics",
        "Bootleg Speed",
        "Darkweb Entheogens",
        "Neuroin",
        "Chain Ale",
        "Virgilium",
        "Red Pills",
        "Cyberpharmetics",
        "Runner's Delight",
        "Rachag",
        "Nuke",
        "Blue Pills",
        "Mystery Pills",
        "Bathtub Aspirin",
        "Muscle",
        "Red Eye",
        "Pirated Petrol",
        "Moon",
        "Stardust",
        "Blues",
        "Carbon Powder",
        "Reds",
        "Synaptizine",
        "Tropicaine",
        "Cortexiphan",
        "Pleuromutilin",
        "Cyalodin",
        "Hydronalin",
        "Squid Ink",
        "Felicium",
        "Snakeleaf",
        "Tropolisine",
        "Synthehol",
        "Maraji Crystals",
        "Ephemerol",
        "Substance D",
        "Adrenochrome",
        "DMT-7",
        "4-Diisopropyltryptamine",
        "Soma",
        "Plutonian Nyborg",
        "Vellocet ",
        "Bootleg Whiskey",
        "Doritos Dust",
        "Blits",
        "OPM"
    ];

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function getWeapon(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "WEAPON", weapons);
    }

    function getClothes(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "CLOTHING", clothing);
    }

    function getVehicle(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "VEHICLE", vehicle);
    }

    function getFoot(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "FOOTWEAR", footwear);
    }

    function getHardware(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "HARDWARE", hardware);
    }

    function getGear(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "GEAR", gear);
    }

    function getContraband(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return pluck(tokenId, "CONTRABAND", contraband);
    }

    function getLoot(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "LOOT", loot);
    }

    function getLocation(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "LOCATION", locations);
    }

    function getDestinations(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return pluck(tokenId, "DESTINATION", destinations);
    }

    function pluck(
        uint256 tokenId,
        string memory keyPrefix,
        string[] memory sourceArray
    ) internal pure returns (string memory) {
        uint256 rand = random(
            string(abi.encodePacked(keyPrefix, toString(tokenId)))
        );
        string memory output = sourceArray[rand % sourceArray.length];
        return output;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {

        string memory svg = string(
            abi.encodePacked(
                '<svg width="350" height="350" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">'
                ' <style type="text/css">text { font-size: 16px; font-family: monospace }</style><path fill="#666666" d="M0 0h350v350H0z"/><path fill="#141d26" d="M7.625 18.94h332.857v318.846H7.625z"/><text x="1" y="19" font-size="14" transform="matrix(.57542 0 0 .51254 7.41 5.37)" font-weight="bold">Mega Mobile</text>'
                '<text font-weight="bold" x="340" y="129.5" font-size="10" font-family="Monospace" transform="matrix(.62 0 0 .62682 78.1 264.932)">POWER(((</text><ellipse cx="339" cy="344" rx="3" ry="3"/><text fill="#56aaff" x="66" y="140" transform="matrix(.63218 0 0 .53353 9.989 18.418)">Weapons:</text><text fill="#fff" x="150" y="140" transform="matrix(.63218 0 0 .53353 9.989 18.418)">',
                getWeapon(tokenId),
                '</text><text fill="#56aaff" x="56" y="175" transform="matrix(.63218 0 0 .53353 9.989 18.418)">Clothing:</text><text fill="#fff" x="149" y="175" transform="matrix(.63218 0 0 .53353 9.989 18.418)">',
                getClothes(tokenId),
                '</text><text fill="#56aaff" x="53" y="211" transform="matrix(.63218 0 0 .53353 9.989 18.418)">Vehicles:</text> <text fill="#fff" x="150" y="211" transform="matrix(.63218 0 0 .53353 9.989 18.418)">',
                getVehicle(tokenId),
                '</text><text fill="#56aaff" x="40" y="246" transform="matrix(.63218 0 0 .53353 9.989 18.418)">Contraband:</text><text fill="#fff" x="152" y="246" transform="matrix(.63218 0 0 .53353 9.989 18.418)">',
                getContraband(tokenId),
                '</text><text fill="#56aaff" x="55" y="280" transform="matrix(.63218 0 0 .53353 9.989 18.418)">Footwear:</text><text fill="#fff" x="151" y="280" transform="matrix(.63218 0 0 .53353 9.989 18.418)">',
                getFoot(tokenId),
                '</text><text fill="#56aaff" x="57" y="312" transform="matrix(.63218 0 0 .53353 9.989 18.418)">Hardware:</text><text fill="#fff" x="153" y="312" transform="matrix(.63218 0 0 .53353 9.989 18.418)">',
                getHardware(tokenId),
                '</text><text fill="#56aaff" x="94" y="348" transform="matrix(.63218 0 0 .53353 9.989 18.418)">Gear:</text><text fill="#fff" x="153" y="348" transform="matrix(.63218 0 0 .53353 9.989 18.418)">',
                getGear(tokenId),
                '</text><text fill="#56aaff" x="92" y="383" transform="matrix(.63218 0 0 .53353 9.989 18.418)">Loot:</text><text fill="#fff" x="154" y="383" transform="matrix(.63218 0 0 .53353 9.989 18.418)">',
                getLoot(tokenId),
                '</text><text fill="#56aaff" x="74" y="509" transform="matrix(.63218 0 0 .53353 9.989 18.418)">Depart:</text><text fill="#fff" x="153" y="509" transform="matrix(.63218 0 0 .53353 9.989 18.418)">',
                getLocation(tokenId),
                '</text><text fill="#56aaff" x="73" y="540" transform="matrix(.63218 0 0 .53353 9.989 18.418)">Arrive:</text><text fill="#fff" x="153" y="540" transform="matrix(.63218 0 0 .53353 9.989 18.418)">',
                getDestinations(tokenId),
                '</text><text fill="#00bf00" x="12" y="21" font-size="12" font-family="Monospace" transform="matrix(.63218 0 0 .53353 9.989 18.418)">Loading Transmission...</text><text fill="#00bf00" x="44" y="96" font-size="12" font-family="Monospace" transform="matrix(.63218 0 0 .53353 9.989 18.418)">DECODING...</text><path d="M52.738 13.268h.57l.175-.541.176.54h.569l-.46.335.175.54-.46-.334-.46.334.175-.54-.46-.334zM57.962-20.562h.569l.176-.54.176.54h.569l-.46.334.175.54-.46-.334-.46.335.175-.541-.46-.334z" fill="#4c4c4c"/><path d="M328.996 11.248h1.75v5.75h-1.75zM332.746 8.748h2v8.25h-2zM336.746 6.248h2.25v10.75h-2.25z"/><text fill="#00bf00" x="20" y="424" font-size="12" font-family="Monospace" transform="matrix(.63218 0 0 .53353 9.989 18.418)">/destinations.scan</text><text fill="#00bf00" x="38" y="465" font-size="12" font-family="Monospace" transform="matrix(.63218 0 0 .53353 9.989 18.418)">DECODING...</text><text font-weight="bold" x="15" y="297" font-size="12" font-family="Monospace" transform="matrix(.65037 0 0 .62682 -2.067 159.599)">Somcom a0.1</text><text fill="#00bf00" x="21" y="62" font-size="12" font-family="Monospace" transform="matrix(.63218 0 0 .53353 9.989 18.418)">/manifest.rootkit</text>'
                "</svg>"
            )
        );

        string memory attributes = string(
            abi.encodePacked(
                ' "attributes":[{"trait_type": "weapons", "value":"',
                getWeapon(tokenId),
                '"},{"trait_type": "clothing", "value": "',
                getClothes(tokenId),
                '"},{"trait_type": "vehicle", "value": "',
                getVehicle(tokenId),
                '"},{"trait_type": "contraband", "value": "',
                getContraband(tokenId),
                '"},{"trait_type": "footwear", "value": "',
                getFoot(tokenId),
                '"},'
            )
        );

        attributes = string(
            abi.encodePacked(
                attributes,
                '{"trait_type": "hardware", "value": "',
                getHardware(tokenId),
                '"},{"trait_type": "gear", "value": "',
                getGear(tokenId),
                '"},{"trait_type": "loot", "value": "',
                getLoot(tokenId),
                '"},{"trait_type": "location", "value": "',
                getLocation(tokenId),
                '"},{"trait_type": "destination", "value": "',
                getDestinations(tokenId),
                '"}]'
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Manifest #',
                        toString(tokenId),
                        '", "description": "WARNING: Unauthorized network access detected. Destroy this confidential com immediately. Failure to do so is a violation of Mega Mobile Terms of Service.", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '",',
                        attributes,
                        "}"
                    )
                )
            )
        );
        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    function claim(uint256 _mintAmount, string calldata key) public payable {
        require(_mintAmount > 0);
        require(_mintAmount <= 10);
        require(mintInfo.nextTokenId + _mintAmount <= mintInfo.maxSupply);

        // Get the hash of the senders address, the runners tokenId, and the key passed
        // This way the key will be different for everyone and they can't just share
        bytes32 sig = keccak256(abi.encodePacked(msg.sender, key));
        uint256 bits = uint256(sig);
        // With a difficulty of 2 we require the last 2 bits to be 0 which gives a 25% hit rate
        uint256 mask = 0x07; // 0x03 is 00000011, aka a byte with the last 2 bits set to true
        require(bits & mask == 0, "INVALID_CODE/ip has been logged");

        if (msg.sender != owner()) {
            require(msg.value >= mintInfo.cost * _mintAmount);
        }

        for (uint256 i = 0; i < _mintAmount; i++) {
            _safeMint(msg.sender, mintInfo.nextTokenId);
            mintInfo.nextTokenId++;
        }
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    constructor() ERC721("bootjack", "BOOT") Ownable() {}
}



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Base64
/// @author Brecht Devos - <brecht@loopring.org>
/// @notice Provides a function for encoding some bytes in base64
library Base64 {
    string internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";

        // load the table into memory
        string memory table = TABLE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {

            } lt(dataPtr, endPtr) {

            } {
                dataPtr := add(dataPtr, 3)

                // read 3 bytes
                let input := mload(dataPtr)

                // write 4 characters
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(input, 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
