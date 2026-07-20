# QB-Core Framework ONLY
## Chop Contracts Custom Script by ProCommando
It is open source, so have fun with it :)



## Items:
### QB Items lua path -> resources -> [qb] -> qb-core -> shared -> open 'items.lua' file.
### Copy and paste the bottom exactly how it is, into your items lua.

-- Chop Contract Items

    chop_contract_easy           = { name = 'chop_contract_easy', label = 'Chopping Contract (Easy)', weight = 0, type = 'item', image = 'easy_contract.png', unique = true, useable = true, shouldClose = true, combinable = nil, description = 'A list of cars to chop - Easy.' },
    chop_contract_medium         = { name = 'chop_contract_medium', label = 'Chopping Contract (Medium)', weight = 0, type = 'item', image = 'medium_contract.png', unique = true, useable = true, shouldClose = true, combinable = nil, description = 'A list of cars to chop - Medium.' },
    chop_contract_hard           = { name = 'chop_contract_hard', label = 'Chopping Contract (Hard)', weight = 0, type = 'item', image = 'hard_contract.png', unique = true, useable = true, shouldClose = true, combinable = nil, description = 'A list of cars to chop - Hard.' },

    chop_cert_easy               = { name = 'chop_cert_easy', label = 'Chopping Certificate (Easy)', weight = 0, type = 'item', image = 'chop_certificate.png', unique = true, useable = false, shouldClose = true, combinable = nil, description = 'Proof of completion. Go hand it in!' },
    chop_cert_medium             = { name = 'chop_cert_medium', label = 'Chopping Certificate (Medium)', weight = 0, type = 'item', image = 'chop_certificate.png', unique = true, useable = false, shouldClose = true, combinable = nil, description = 'Proof of completion. Go hand it in!' },
    chop_cert_hard               = { name = 'chop_cert_hard', label = 'Chopping Certificate (Hard)', weight = 0, type = 'item', image = 'chop_certificate.png', unique = true, useable = false, shouldClose = true, combinable = nil, description = 'Proof of completion. Go hand it in!' },

    chop_part_door               = { name = 'chop_part_door', label = 'Chop Part: Door', weight = 2000, type = 'item', image = 'chop_door.png', unique = true, useable = false, shouldClose = true, combinable = nil, description = 'A salvaged door.' },
    chop_part_wheel              = { name = 'chop_part_wheel', label = 'Chop Part: Wheel', weight = 1500, type = 'item', image = 'chop_wheel.png', unique = true, useable = false, shouldClose = true, combinable = nil, description = 'A salvaged wheel.' },
    chop_part_bonnet             = { name = 'chop_part_bonnet', label = 'Chop Part: Bonnet', weight = 2000, type = 'item', image = 'chop_bonnet.png', unique = true, useable = false, shouldClose = true, combinable = nil, description = 'A salvaged bonnet.' },
    chop_part_trunk              = { name = 'chop_part_trunk', label = 'Chop Part: Trunk', weight = 2000, type = 'item', image = 'chop_trunk.png', unique = true, useable = false, shouldClose = true, combinable = nil, description = 'A salvaged trunk.' },



## Images:
### QB Images path -> resources -> [qb] -> qb-inventory -> html -> open 'images' folder.
Copy and paste the 8 images, into your images folder.

## How to find the item:
This is where you need to know what you're doing with looting items in your server.
You can add the item in qb-trashsearch to find easy and/or medium contracts, put in hard contracts in your house robberies, etc. 

You decide where the items should be found, as one of the choice. 
Note: When adding the items, make sure it's the item name such as "chop_contract_easy" - It must match exactly how it is in items lua otherwise you will run into issues.



## Shared - Config file:
### This is where you can change whatever you like to your liking and to establish appropriate economy to your server.

**Chop Zones** = Coordinates of where the cars are allowed to be chopped. Recommend 25.0 for smaller enclosed areas or 50.0 for bigger areas. 
The car has to be in the radius before you can begin chopping it.

**Contract Flow** = I wouldn't recommend changing anything here unless you know what you're doing. 

**Certificate Rewards** = You can change the numbers here to your preference/economy of the server.

**Items** = DON'T CHANGE ANYTHING HERE.

**Physical** = DON'T CHANGE ANYTHING HERE.

**Vehicle Pools** = Upto you how you want to assign cars. It's already preset for you, but you can add more cars if you like. 
If you add any cars, make sure it's also in your vehicles lua otherwise it won't work. 
Vehicle lua path -> resources -> [qb] -> qb-core -> shared -> open 'vehicles.lua' file.

**Rep System** = If you don't want a rep system, make enabled = false, otherwise you can change the numbers to your preference.

**Pinning** = When someone has 2 contracts with the same car, they can pin a specific contract so that it only takes the car off of that list when chopping.
When no contracts are pinned, it chooses a random contract for that car when chopped.

**Part Quality** = If you don't want a rep system, make enabled = false, otherwise you can change the numbers to your preference.
The higher the rep level, the higher changes of getting higher quality parts. Therefore the part quality is tied to your rep level.

**Chopping NPC** = If you don't have an NPC, make enabled - false, otherwise you can place the coords of where you want the NPC to be. 
You can change the reward to cash or keep it as markedbills. You can change reward prices for chopped parts as well.

### Chopping Certificate only grants markedbills as rewards, whereas chopped parts can grant cash or markedbills whichever you choose.


# Script Issues:
If you run into any issues, please open an issue by going here -> https://github.com/procommando/pc_chopshop/issues and explain in detail as much as you can. 
### I can't promise any assitance, but I will do my best. This is my first custom script, so please bare with me.






