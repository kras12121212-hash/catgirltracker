-- Centralized chat messages
-- Keep the  %s or %d placeholders they insert the variables 
CCT_Messages = {
    -- HeadPetTracker
    HEADPET_SPANKED = "Was a Bad Kitten and got spanked from %s",
    HEADPET_EARPINCH = "Was a Bad Kitten and got pinched in the ear from %s",
    HEADPET_GOOD = "Was a good Kitten and received a %s from %s",

    -- InnSlackerTracker
    INN_SLACKING = "Was caught slagging off in the inn again nya!",

    -- PetTracker
    PET_SUMMON_GOOD = "Was a good kitten and rembered to summon their Cat",
    PET_SUMMON_BAD = "Was a Bad Kitten and forgot to summon their cat",

    -- NapTracker (guild + optional debug say)
    NAP_WOKE_EARLY = "Was told to take her kitty Nap but was a cranky kitten that got up to early",
    NAP_OVERSLEPT = "Was told to take a Nap but decided to sleep all day ! Bad Lazy Kitten !",
    NAP_SLEPT_AS_TOLD = "Was a good kitten and took a nap as told make sure to give her headpets and praises Nya",
    NAP_DID_NOT_SLEEP = "Was told to take a Nap but did not Listen and should be punished by her owner.",
    NAP_DEBUG_WOKE_EARLY = "DEBUG: WokeUpToEarly",
    NAP_DEBUG_OVERSLEPT_MOVE = "DEBUG: Oversleept (after move)",
    NAP_DEBUG_SLEPT_AS_TOLD = "DEBUG: SleeptAsTold",
    NAP_DEBUG_OVERSLEPT_NOMOVE = "DEBUG: Oversleept (no move)",
    NAP_DEBUG_DID_NOT_SLEEP = "DEBUG: DidNotSleep",

    -- Gag
    GAG_HEAVY = "Has been gagged with a huge gag NYA!!! She's already whimpering... );",
    GAG_SMALL = "Has been gagged with a small gag. Hopefully that will be a lesson.",
    GAG_FULLBLOCK = "She has been fully masked and gagged... not a sound can escape! Nya~",
    GAG_INFLATABLE = "An inflatable gag is now in place. She can still mumble... for now.",
    GAG_INFLATE = "Inflated the gag. She's even more muffled now.",
    GAG_DEFLATE = "Deflated the gag slightly. She can mumble a bit more.",
    GAG_REMOVE = "Has been ungagged. She may speak freely again~",
    GAG_NYAMASK = "Has been given a cute kitten mask. She's meowing every sentence! UwU",

    -- Leash
    LEASH_APPLY = "You have clipped the leash onto %s... There's no escape now, nya~",
    LEASH_REMOVE = "The leash slips free from %s. She's free... for now nya~",

    -- Blindfold
    BLINDFOLD_LIGHT = "Oh Nyo a blurry light blindfold... should better Behave or it gets worse!",
    BLINDFOLD_KITTY = "Wearing a cute kitty blindfold... vision limited nya~",
    BLINDFOLD_FULL = "Can't see anything! It's all black nya!",
    BLINDFOLD_REMOVE = "Blindfold removed... finally I can see again nya~",

    -- PawMittens
    PAW_MITTENS_SAY = "Oh no looks like kitten has trouble using her spells with her Paws nya!",
    PAW_MITTENS_RESPONSE_SQUEAKING = "Squeaking paw mittens have been locked onto your kitten's paws. They only swap her spells briefly every 30 seconds and squeak whenever she casts.",
    PAW_MITTENS_RESPONSE_LOCKED = "Tight paw mittens have been locked onto your kitten's paws. They are reinforced, so she cannot use her paws properly or extend her claws at all.",
    PAW_MITTENS_REMOVE = "Your paw mittens have been removed. Your paws and claws are free again nya~",

    -- LockingKittenHeels
    HEELS_PROGRESS = "Yeah \"%s\" Is Making Progress Learning How to walk in her \"%s\" she just reached lvl \"%d\"",
    HEELS_FAIL = "Oh no \"%s\" Just fell trying to walk in her \"%s\" she should be more careful and take it slow or she will be stuck at Level \"%d\" forever Nya~",
    HEELS_RESPONSE_MAID = "Locking maid heels (3 cm) have been secured. The higher the heel, the harder it is to walk.",
    HEELS_RESPONSE_HIGH = "Locking high heels (8 cm) have been secured. The higher the heel, the harder it is to walk.",
    HEELS_RESPONSE_BALLET = "Locking ballet boots (12 cm) have been secured. The higher the heel, the harder it is to walk.",
    HEELS_RESPONSE_GENERIC = "Heels are locked on.",
    HEELS_REMOVE = "Your heels have been removed. Your feet are free again.",
}

function CCT_GetMessage(key, ...)
    local template = CCT_Messages and CCT_Messages[key]
    if not template then
        return tostring(key or "")
    end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, template, ...)
        if ok then
            return formatted
        end
    end
    return template
end

function CCT_Msg(key, ...)
    return CCT_GetMessage(key, ...)
end
