-- Centralized chat messages
-- Keep the  %s or %d placeholders they insert the variables 
CCT_Messages = {
    -- HeadPetTracker
    HEADPET_SPANKED = "Was a bad kitten, and got spanked by %s.",
    HEADPET_EARPINCH = "Was a bad kitten, and got pinched in the ear by %s.",
    HEADPET_GOOD = "Was a good kitten, and received a %s from %s.",

    -- InnSlackerTracker
    INN_SLACKING = "Was caught slacking off in the inn again, nya!",

    -- PetTracker
    PET_SUMMON_GOOD = "Was a good kitten, and remembered to summon their cat",
    PET_SUMMON_BAD = "Was a bad kitten, and forgot to summon their cat",

    -- NapTracker (guild + optional debug say)
    NAP_WOKE_EARLY = "Was told to take her kitty nap, but was a cranky kitten that got up too early",
    NAP_OVERSLEPT = "Was told to take a nap, but decided to sleep all day! Bad, lazy kitten!",
    NAP_SLEPT_AS_TOLD = "Was a good kitten, and took a nap as instructed. Make sure to give her headpets and praise, nya!",
    NAP_DID_NOT_SLEEP = "Was told to take a nap, but did not listen, and should be punished by her owner.",
    NAP_DEBUG_WOKE_EARLY = "DEBUG: WokeUpToEarly",
    NAP_DEBUG_OVERSLEPT_MOVE = "DEBUG: Overslept (after move)",
    NAP_DEBUG_SLEPT_AS_TOLD = "DEBUG: SleptAsTold",
    NAP_DEBUG_OVERSLEPT_NOMOVE = "DEBUG: Overslept (no move)",
    NAP_DEBUG_DID_NOT_SLEEP = "DEBUG: DidNotSleep",

    -- Gag
    GAG_HEAVY = "Has been gagged with a huge gag, NYA!!! She's already whimpering... );",
    GAG_SMALL = "Has been gagged with a small gag. Hopefully that will be a lesson.",
    GAG_FULLBLOCK = "She has been fully masked and gagged... Not a sound can escape now! Nya~",
    GAG_INFLATABLE = "An inflatable gag is now in place. She can still mumble... For now.",
    GAG_INFLATE = "Inflated the gag. She's even more muffled now.",
    GAG_DEFLATE = "Deflated the gag slightly. She can mumble a bit more.",
    GAG_REMOVE = "Has been ungagged. She may speak freely again~",
    GAG_NYAMASK = "Has been been masked with a cute kitty mask. She's meowing every sentence! UwU",

    -- Leash
    LEASH_APPLY = "You have clipped the leash onto %s... There's no escape now, nya~",
    LEASH_REMOVE = "The leash slips free from %s. She's free... For now, nya~",

    -- Blindfold
    BLINDFOLD_LIGHT = "Oh nyo! A blurry light blindfold... I should better behave, or it may get worse!",
    BLINDFOLD_KITTY = "Wearing a cute kitty blindfold... Vision limited, nya~",
    BLINDFOLD_FULL = "Can't see anything! It's all black, nya!",
    BLINDFOLD_REMOVE = "Blindfold removed... Finally, I can see again, nya~",

    -- PawMittens
    PAW_MITTENS_SAY = "Oh no, looks like kitten has trouble using her spells thanks to these paws, nya!",
    PAW_MITTENS_RESPONSE_SQUEAKING = "Squeaking paw mittens have been locked onto your kitten's paws. They swap her spells briefly every 30 seconds, and squeak whenever she casts.",
    PAW_MITTENS_RESPONSE_LOCKED = "Tight paw mittens have been locked onto your kitten's paws. They are reinforced, so she cannot use her paws properly, or extend her claws at all.",
    PAW_MITTENS_REMOVE = "Your paw mittens have been removed. Your paws and claws are free again, nya~",

    -- LockingkittenHeels
    HEELS_PROGRESS = "Yay, \"%s\" is making progress learning how to walk in her \"%s\", she just reached level \"%d\"!",
    HEELS_FAIL = "Oh no.. \"%s\" just fell trying to walk in her \"%s\", she should be more careful and take it slow, or she will be stuck at level \"%d\" forever, nya~",
    HEELS_RESPONSE_MAID = "Maid heels (3 cm) were equipped and securely locked in place. The higher the heel, the harder it is to walk.",
    HEELS_RESPONSE_HIGH = "High heels (8 cm) were equipped and securely locked in place. The higher the heel, the harder it is to walk.",
    HEELS_RESPONSE_BALLET = "Ballet boots (12 cm) were equipped and securely locked in place. The higher the heel, the harder it is to walk.",
    HEELS_RESPONSE_GENERIC = "Heels are fitted and locked shut.",
    HEELS_REMOVE = "Your heels have been removed. Your feet are free again.",

    -- Chastity
    CHASTITY_BELT_APPLY = "A chastity belt has been locked in place. Your kitten's pleasure is sealed away.",
    CHASTITY_BELT_REMOVE = "The chastity belt has been removed. Your kitten can feel again.",
    CHASTITY_BELT_DENY = "The chastity belt is set to Deny Orgasm. She will be kept on the edge.",
    CHASTITY_BELT_ALLOW = "The chastity belt is set to Allow Orgasm. She may climax if she earns it.",
    CHASTITY_BRA_APPLY = "A chastity bra has been locked in place. Her chest is sealed and denied.",
    CHASTITY_BRA_REMOVE = "The chastity bra has been removed. Her chest is free again.",
    CHASTITY_DENY_SHOCK = "Your kitten almost Reached climax but the Magic Chastity Belt keept her in check with a harsh shock to her pussy.",
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
