*=======================================================
* TEXT QUEST  (Easy68K / Sim68K)
* v2.0 - Monsters: Skeleton, Orc, Giant, Dragon
*         Epic & Legendary loot system
*
* REGISTER CONVENTIONS used throughout:
*   D0  - scratch / return value from subroutines
*   D1  - TRAP #15 task number (I/O) / scratch
*   D2  - working register for arithmetic
*   D3  - secondary scratch (ROLL_LOOT only)
*   A1  - pointer to string for PRINT_STR
*   A7  - stack pointer (used by MOVEM in ENDL)
*=======================================================
        ORG     $1000           ; program starts at address $1000

*-------------------------------------------------------
* CONSTANTS
*-------------------------------------------------------
EXIT            EQU     0       ; value that causes REPLAY to exit the game
MIN_POTIONS     EQU     1       ; minimum bravery potions at start
MAX_POTIONS     EQU     5       ; maximum bravery potions at start
WIN_POINT       EQU     2       ; bravery bonus for a safe step
LOSE_POINT      EQU     8       ; bravery penalty when fleeing a monster
MAX_LOC         EQU     12      ; path length -> win when LOCATION >= 12

* Monster type IDs stored in CURRENT_MONSTER
MON_GIANT       EQU     1       ; Stone Giant  -> locations 8-10
MON_SKELETON    EQU     2       ; Skeleton     -> locations 1-3
MON_ORC         EQU     3       ; Orc          -> locations 4-7
MON_DRAGON      EQU     4       ; Fire Dragon  -> locations 11-12

* Loot rarity levels returned by ROLL_LOOT in D0
LOOT_NONE       EQU     0       ; no loot drop
LOOT_EPIC       EQU     1       ; epic item
LOOT_LEGENDARY  EQU     2       ; legendary item

*=======================================================
* ENTRY POINT
*=======================================================
START:
        BSR     CLEAR_SCREEN            ; wipe the screen before showing anything

        MOVE.B  #10, BRAVERY            ; default bravery (overwritten by hero selection)
        CLR.B   DANGER_TICK             ; reset the danger step counter
        CLR.B   MONSTER_COUNTER         ; reset total kills for this run

        BSR     WELCOME                 ; print the game title banner

*-------------------------------------------------------
* MAIN MENU -> configure the character before each run
*-------------------------------------------------------
MAIN_MENU:
        BSR     CHOOSE_HERO             ; pick class: Archer / Knight / Wizard
        BSR     GET_POTIONS             ; choose starting bravery potions (1..5)
        BSR     GET_WEAPONS             ; choose starting weapon (1..3)
        BSR     CHOOSE_DIFFICULTY       ; pick difficulty (1=Easy 2=Normal 3=Hard)

        BSR     GAMEPLAY                ; run the main adventure loop
        BSR     HUD                     ; show the end-of-run summary screen

        BSR     REPLAY                  ; ask: play again?
        CMP.L   #EXIT, D1               ; if player entered 0 -> exit
        BEQ     END_GAME

        BSR     CLEAR_SCREEN            ; otherwise clear screen and loop
        BRA     MAIN_MENU

END_GAME:
        BSR     ENDL
        LEA     BYE_MSG, A1
        BSR     PRINT_STR
        SIMHALT                         ; stop the simulator

*=======================================================
* WELCOME -> print the title screen
*=======================================================
WELCOME:
        BSR     ENDL
        LEA     WELCOME_MSG, A1
        BSR     PRINT_STR
        RTS

*=======================================================
* CHOOSE_HERO -> let the player pick a class
*
* Classes:
*   1 = Archer  -> 70 HP, 10 arrows, bow costs 1 arrow per attack
*   2 = Knight  -> 80 HP, no resources needed, sword always works
*   3 = Wizard  -> 70 HP, 100 mana, staff costs 20 mana per cast
*                 Dragon deals -50% damage to Wizard
*
* Writes: PLAYER_CLASS, PLAYER_ARROWS, PLAYER_MANA,
*         BRAVERY, MANA_POTIONS_COUNT
*=======================================================
CHOOSE_HERO:
        BSR     ENDL
        LEA     HERO_MSG, A1
        BSR     PRINT_STR               ; show the hero selection menu

.READ:
        BSR     READ_NUM                ; read integer input -> D1 via TRAP #15

        CMP.L   #1, D1
        BEQ     .ARCHER                 ; 1 -> Archer
        CMP.L   #2, D1
        BEQ     .KNIGHT                 ; 2 -> Knight
        CMP.L   #3, D1
        BEQ     .WIZARD                 ; 3 -> Wizard

        LEA     INVALID_HERO_MSG, A1    ; bad input -> prompt again
        BSR     PRINT_STR
        BRA     .READ

.ARCHER:
        LEA     HERO_ARCHER_MSG, A1
        BSR     PRINT_STR
        MOVE.B  #1, PLAYER_CLASS        ; class id = 1 (Archer)
        MOVE.B  #10, PLAYER_ARROWS      ; start with 10 arrows
        MOVE.B  #0, PLAYER_MANA         ; no mana
        MOVE.B  #70, BRAVERY            ; starting bravery
        MOVE.B  #0, MANA_POTIONS_COUNT  ; no mana potions
        RTS

.KNIGHT:
        LEA     HERO_KNIGHT_MSG, A1
        BSR     PRINT_STR
        MOVE.B  #2, PLAYER_CLASS        ; class id = 2 (Knight)
        MOVE.B  #80, BRAVERY            ; boosted bravery (60 base + 20 bonus)
        MOVE.B  #0, PLAYER_MANA         ; no mana
        MOVE.B  #0, PLAYER_ARROWS       ; no arrows
        MOVE.B  #0, MANA_POTIONS_COUNT  ; no mana potions
        RTS

.WIZARD:
        LEA     HERO_WIZARD_MSG, A1
        BSR     PRINT_STR
        MOVE.B  #3, PLAYER_CLASS        ; class id = 3 (Wizard)
        MOVE.B  #70, BRAVERY            ; starting bravery
        MOVE.B  #100, PLAYER_MANA       ; start with 100 mana
        MOVE.B  #0, PLAYER_ARROWS       ; no arrows
        MOVE.B  #2, MANA_POTIONS_COUNT  ; bonus: 2 mana potions
        RTS

*=======================================================
* GET_POTIONS -> choose how many bravery potions to start with
*
* Valid range: MIN_POTIONS(1) .. MAX_POTIONS(5)
* Each potion restores +10 bravery when used in-game
* Writes: BRAVERY_POTIONS_COUNT
*=======================================================
GET_POTIONS:
        BSR     ENDL
        LEA     POTIONS_MSG, A1
        BSR     PRINT_STR

.READ:
        BSR     READ_NUM                ; D1 = player input
        CMP.L   #MIN_POTIONS, D1
        BLT     .BAD                    ; below 1 -> reject
        CMP.L   #MAX_POTIONS, D1
        BGT     .BAD                    ; above 5 -> reject

        MOVE.B  D1, BRAVERY_POTIONS_COUNT   ; store chosen potion count
        RTS

.BAD:
        LEA     POTIONS_BAD_MSG, A1
        BSR     PRINT_STR
        BRA     .READ

*=======================================================
* GET_WEAPONS -> choose starting weapon
*
*   1 = Bow    -> 20 damage, consumes 1 arrow per hit
*   2 = Sword  -> 15 damage, no resource cost
*   3 = Staff  -> 25 damage, consumes 20 mana per hit
*
* Writes: WEAPON, PLAYER_DMG
*=======================================================
GET_WEAPONS:
        BSR     ENDL
        LEA     WEAPONS_MSG, A1
        BSR     PRINT_STR

.READ:
        BSR     READ_NUM
        CMP.B   #1, D1
        BLT     .BAD
        CMP.B   #3, D1
        BGT     .BAD

        MOVE.B  D1, WEAPON              ; store weapon choice (1/2/3)

        CMP.B   #1, WEAPON
        BEQ     .BOW
        CMP.B   #2, WEAPON
        BEQ     .SWORD
        BRA     .STAFF                  ; else -> staff

.BOW:   MOVE.B  #20, PLAYER_DMG        ; bow: 20 damage
        RTS
.SWORD: MOVE.B  #15, PLAYER_DMG        ; sword: 15 damage
        RTS
.STAFF: MOVE.B  #25, PLAYER_DMG        ; staff: 25 damage
        RTS

.BAD:
        LEA     WEAPONS_BAD_MSG, A1
        BSR     PRINT_STR
        BRA     .READ

*=======================================================
* CHOOSE_DIFFICULTY -> pick difficulty level
*
*   1 = Easy   -> monster every 5 steps, base damage
*   2 = Normal -> monster every 4 steps, monster dmg +4
*   3 = Hard   -> monster every 3 steps, monster dmg +8
*
* Writes: DIFFICULTY
*=======================================================
CHOOSE_DIFFICULTY:
        BSR     ENDL
        LEA     DIFF_MSG, A1
        BSR     PRINT_STR

.READ:
        BSR     READ_NUM
        CMP.L   #1, D1
        BLT     .BAD
        CMP.L   #3, D1
        BGT     .BAD

        MOVE.B  D1, DIFFICULTY
        RTS

.BAD:
        LEA     DIFF_BAD_MSG, A1
        BSR     PRINT_STR
        BRA     .READ

*=======================================================
* GAMEPLAY -> main adventure loop
*
* Each turn the player picks an action:
*   1 = Move forward  -> LOCATION++, danger check
*   2 = Rest          -> BRAVERY+5; 3 in a row spawns a monster
*   3 = Use potion    -> BRAVERY+10, BRAVERY_POTIONS_COUNT--
*   4 = Use mana pot  -> MANA+20,   MANA_POTIONS_COUNT--
*
* Win condition:  LOCATION >= MAX_LOC (12)
* Lose condition: BRAVERY <= 0
*=======================================================
GAMEPLAY:
        BSR     ENDL
        LEA     GAMEPLAY_MSG, A1
        BSR     PRINT_STR
        CLR.B   DANGER_TICK             ; reset danger step counter
        CLR.B   LOCATION                ; start at position 0
        CLR.B   REST_COUNTER            ; reset consecutive rest counter
        MOVE.B  #100, GIANT_HEALTH_LEFT ; giant retains HP between encounters

GAMEPLAY_LOOP:
        TST.B   BRAVERY                 ; is bravery zero?
        BEQ     GAME_OVER               ; yes -> game over

        CMP.B   #MAX_LOC, LOCATION      ; reached the end of the path?
        BGE     .WIN                    ; LOCATION >= 12 -> victory

        BSR     STATUS_LINE             ; print the player status bar

        LEA     ACTION_MSG, A1
        BSR     PRINT_STR               ; show the action menu
        BSR     READ_NUM                ; read choice into D1

        CMP.L   #1, D1
        BEQ     .DO_MOVE                ; 1 -> move forward
        CMP.L   #2, D1
        BEQ     .DO_REST                ; 2 -> rest
        CMP.L   #3, D1
        BEQ     .DO_POTION              ; 3 -> bravery potion
        CMP.L   #4, D1
        BEQ     .DO_MANA_POTION         ; 4 -> mana potion

        LEA     ACTION_BAD_MSG, A1      ; invalid input
        BSR     PRINT_STR
        BRA     GAMEPLAY_LOOP

*--- Rest action ---
.DO_REST:
        ADD.B   #1, REST_COUNTER        ; count consecutive rests
        MOVEQ   #0, D2
        MOVE.B  BRAVERY, D2
        ADDQ.L  #5, D2                  ; +5 bravery (32-bit add to compare with 255 safely)
        CMP.L   #255, D2                ; would it exceed 255?
        BLE     .R_OK
        MOVE.L  #255, D2                ; cap at 255
.R_OK:
        MOVE.B  D2, BRAVERY
        CMP.B   #3, REST_COUNTER        ; rested 3 times in a row?
        BNE     .REST_SAFE              ; no -> just print rest message
        ; Yes -> a monster sneaks up; reset counter and start combat
        CLR.B   REST_COUNTER            ; NOTE: CLR.B (1 byte), NOT CLR.W!
                                        ; CLR.W would corrupt CURRENT_MONSTER
                                        ; because it sits right after REST_COUNTER in memory
        BSR     PICK_MONSTER            ; pick monster type for current location
        BSR     COLLISION               ; run the battle (BSR = proper call with return)
        BRA     GAMEPLAY_LOOP
.REST_SAFE:
        LEA     REST_MSG, A1
        BSR     PRINT_STR
        BRA     GAMEPLAY_LOOP

*--- Bravery potion action ---
.DO_POTION:
        TST.B   BRAVERY_POTIONS_COUNT   ; any potions left?
        BEQ     .NO_POT                 ; none -> show message
        SUBQ.B  #1, BRAVERY_POTIONS_COUNT   ; consume 1 potion
        MOVEQ   #0, D2
        MOVE.B  BRAVERY, D2
        ADD.L   #10, D2                 ; +10 bravery (32-bit for safe cap compare)
        CMP.L   #255, D2
        BLE     .P_OK
        MOVE.L  #255, D2
.P_OK:
        MOVE.B  D2, BRAVERY
        LEA     POT_USED_MSG, A1
        BSR     PRINT_STR
        BRA     GAMEPLAY_LOOP

*--- Mana potion action ---
.DO_MANA_POTION:
        TST.B   MANA_POTIONS_COUNT      ; any mana potions left?
        BEQ     .NO_POT
        SUBQ.B  #1, MANA_POTIONS_COUNT  ; consume 1 mana potion
        MOVEQ   #0, D2
        MOVE.B  PLAYER_MANA, D2
        ADD.B   #20, D2                 ; +20 mana
        CMP.L   #255, D2
        BLE     .P_OK_MANA
        MOVE.L  #255, D2
.P_OK_MANA:
        MOVE.B  D2, PLAYER_MANA
        LEA     POT_MANA_USED_MSG, A1
        BSR     PRINT_STR
        BRA     GAMEPLAY_LOOP

.NO_POT:
        LEA     NO_POT_MSG, A1
        BSR     PRINT_STR
        BRA     GAMEPLAY_LOOP

*--- Move forward action ---
.DO_MOVE:
        ADDQ.B  #1, LOCATION            ; step forward

        BSR     ENDL
        LEA     STEP_MSG, A1
        BSR     PRINT_STR               ; "Moved forward. Location: "
        MOVEQ   #0, D1
        MOVE.B  LOCATION, D1
        BSR     PRINT_NUM               ; print location number
        BSR     ENDL

        BSR     DANGER_CHECK            ; returns D0=1 if danger, D0=0 if safe
        TST.B   D0
        BEQ     .SAFE                   ; D0=0 -> safe step

        ; Danger! Spawn a monster and enter combat
        BSR     PICK_MONSTER            ; sets CURRENT_MONSTER by location
        BSR     COLLISION               ; battle loop (BSR = correct call with return)
        BRA     GAMEPLAY_LOOP

*--- Safe step ---
.SAFE:
        LEA     SAFE_MSG, A1
        BSR     PRINT_STR               ; "Safe move!"
        BSR     ADD_BRAVERY_WIN         ; +WIN_POINT(2) bravery
        LEA     SAFE_CHOICE_MSG, A1
        BSR     PRINT_STR               ; offer a reward choice
        BSR     READ_NUM

        CMP.B   #1, D1
        BEQ     .BRV_POTIONS_SAFE       ; 1 -> bravery potion
        CMP.B   #2, D1
        BEQ     .ADD_ARROW_SAFE         ; 2 -> 2 arrows
        CMP.B   #3, D1
        BEQ     .MANA_POTIONS_SAFE      ; 3 -> mana potion
        BRA     GAMEPLAY_LOOP           ; invalid -> skip reward

.ADD_ARROW_SAFE:
        MOVE.B  #2, D1
        ADD.B   D1, PLAYER_ARROWS       ; +2 arrows
        LEA     GOT_ARROWS_MSG, A1
        BSR     PRINT_STR
        BRA     GAMEPLAY_LOOP

.MANA_POTIONS_SAFE:
        MOVE.B  #1, D1
        ADD.B   D1, MANA_POTIONS_COUNT  ; +1 mana potion
        LEA     GOT_MANA_POT_MSG, A1
        BSR     PRINT_STR
        BRA     GAMEPLAY_LOOP

.BRV_POTIONS_SAFE:
        MOVE.B  #1, D1
        ADD.B   D1, BRAVERY_POTIONS_COUNT   ; +1 bravery potion
        LEA     GOT_BRV_POT_MSG, A1
        BSR     PRINT_STR
        BRA     GAMEPLAY_LOOP

*--- Victory ---
.WIN:
        BSR     ENDL
        LEA     JOURNEY_WIN_MSG, A1
        BSR     PRINT_STR
        RTS                             ; return to MAIN_MENU -> HUD

*--- Defeat ---
GAME_OVER:
        BSR     ENDL
        LEA     GAME_OVER_MSG, A1
        BSR     PRINT_STR
        BRA     REPLAY                  ; jump straight to replay screen

*=======================================================
* PICK_MONSTER -> choose monster type based on location
*
* Input:  LOCATION (global variable)
* Output: CURRENT_MONSTER and CURRENT_MON_HP are set
*
* Zone logic:
*   Locations 1-3  -> Skeleton (30 HP)  -> early, weak enemy
*   Locations 4-7  -> Orc     (60 HP)  -> mid zone
*   Locations 8-10 -> Giant   (GIANT_HEALTH_LEFT HP) -> carries HP across encounters
*   Locations 11+  -> Dragon  (120 HP) -> final boss
*=======================================================
PICK_MONSTER:
        MOVEQ   #0, D0
        MOVE.B  LOCATION, D0            ; load current location into D0

        CMP.B   #3, D0
        BLE     .SET_SKEL               ; location <= 3 -> skeleton

        CMP.B   #7, D0
        BLE     .SET_ORC                ; location <= 7 -> orc

        CMP.B   #10, D0
        BLE     .SET_GIANT              ; location <= 10 -> giant

        BRA     .SET_DRAGON             ; else -> dragon

.SET_SKEL:
        MOVE.B  #MON_SKELETON, CURRENT_MONSTER
        MOVE.B  #30, CURRENT_MON_HP     ; skeleton has 30 HP
        RTS

.SET_ORC:
        MOVE.B  #MON_ORC, CURRENT_MONSTER
        MOVE.B  #60, CURRENT_MON_HP     ; orc has 60 HP
        RTS

.SET_GIANT:
        MOVE.B  #MON_GIANT, CURRENT_MONSTER
        MOVE.B  GIANT_HEALTH_LEFT, CURRENT_MON_HP   ; giant remembers HP between fights
        RTS

.SET_DRAGON:
        MOVE.B  #MON_DRAGON, CURRENT_MONSTER
        MOVE.B  #120, CURRENT_MON_HP    ; dragon has 120 HP
        RTS

*=======================================================
* DANGER_CHECK -> decide if danger occurs on this step
*
* Uses a deterministic tick counter DANGER_TICK:
*   Easy:   danger every 5 steps
*   Normal: danger every 4 steps
*   Hard:   danger every 3 steps
*
* Input:  DIFFICULTY, DANGER_TICK
* Output: D0 = 1 (danger) / 0 (safe)
*         DANGER_TICK is reset when it fires
*=======================================================
DANGER_CHECK:
        MOVEQ   #0, D0                  ; D0 = 0, assume no danger
        MOVEQ   #0, D2
        MOVE.B  DIFFICULTY, D2          ; load difficulty
        CMP.B   #1, D2
        BEQ     .EASY
        CMP.B   #2, D2
        BEQ     .NORMAL
        BRA     .HARD

.EASY:   MOVEQ   #5, D2                 ; trigger threshold = 5 steps
         BRA     .TICK
.NORMAL: MOVEQ   #4, D2                 ; threshold = 4 steps
         BRA     .TICK
.HARD:   MOVEQ   #3, D2                 ; threshold = 3 steps

.TICK:
        ADDQ.B  #1, DANGER_TICK         ; increment step counter
        MOVEQ   #0, D1
        MOVE.B  DANGER_TICK, D1
        CMP.B   D2, D1                  ; TICK == threshold?
        BNE     .DONE                   ; no -> safe, leave D0=0
        MOVEQ   #1, D0                  ; yes -> danger, D0=1
        CLR.B   DANGER_TICK             ; reset counter for next cycle
.DONE:
        RTS

*=======================================================
* COLLISION -> monster encounter and battle loop
*
* Called via BSR after PICK_MONSTER has set up the monster.
* CURRENT_MONSTER and CURRENT_MON_HP are already filled.
*
* Flow:
*   1. Print monster intro + set base damage for this monster type
*   2. Scale monster damage up by difficulty
*   3. Loop .LOOP:
*        - check player/monster death
*        - show combat HUD
*        - player chooses: Fight(1) or Run(2)
*        - .FIGHT: check resources, deal damage both ways
*        - .RUN:   bravery penalty, step back, RTS
*
* Monster base damage (before difficulty scaling):
*   Skeleton=8, Orc=12, Giant=15, Dragon=22
* Difficulty scaling: Easy +0, Normal +4, Hard +8
*=======================================================
COLLISION:
        ; --- Print intro and set base damage based on monster type ---
        MOVEQ   #0, D0
        MOVE.B  CURRENT_MONSTER, D0     ; load monster type
        CMP.B   #MON_SKELETON, D0
        BEQ     .INTRO_SKEL
        CMP.B   #MON_ORC, D0
        BEQ     .INTRO_ORC
        CMP.B   #MON_DRAGON, D0
        BEQ     .INTRO_DRAG
        BRA     .INTRO_GIANT            ; fallthrough = Giant (MON_GIANT=1)

.INTRO_SKEL:
        LEA     MON_SKEL_INTRO, A1
        BSR     PRINT_STR
        MOVE.B  #8, CURRENT_MON_DMG     ; skeleton base damage = 8
        BRA     .DIFF_DMG

.INTRO_ORC:
        LEA     MON_ORC_INTRO, A1
        BSR     PRINT_STR
        MOVE.B  #12, CURRENT_MON_DMG    ; orc base damage = 12
        BRA     .DIFF_DMG

.INTRO_GIANT:
        LEA     MON_GIANT_INTRO, A1
        BSR     PRINT_STR
        MOVE.B  #15, CURRENT_MON_DMG    ; giant base damage = 15
        BRA     .DIFF_DMG

.INTRO_DRAG:
        LEA     MON_DRAG_INTRO, A1
        BSR     PRINT_STR
        MOVE.B  #22, CURRENT_MON_DMG    ; dragon base damage = 22
        ; fall through into .DIFF_DMG

.DIFF_DMG:
        ; --- Scale monster damage by difficulty ---
        CMP.B   #2, DIFFICULTY
        BLT     .DIFF_DONE              ; Easy (1) -> no change
        CMP.B   #2, DIFFICULTY
        BEQ     .NORM_DMG               ; Normal (2) -> +4
        ADD.B   #8, CURRENT_MON_DMG     ; Hard (3) -> +8
        BRA     .DIFF_DONE
.NORM_DMG:
        ADD.B   #4, CURRENT_MON_DMG

.DIFF_DONE:
        BSR     SHOW_MONSTER_HUD        ; show monster HP and player HP

*--- Main combat loop ---
.LOOP:
        TST.B   BRAVERY                 ; is the player dead?
        BEQ     GAME_OVER

        ; Check monster death using 32-bit load to avoid signed-byte false positive.
        ; A byte value of 128-255 would look negative to TST.B, so we zero-extend
        ; into a 32-bit register and test that instead.
        MOVEQ   #0, D0
        MOVE.B  CURRENT_MON_HP, D0      ; zero-extend HP into 32-bit D0
        TST.L   D0                      ; test as 32-bit signed value
        BLE     .MONSTER_DEAD           ; <= 0 -> monster is dead

        BSR     SHOW_MONSTER_HUD        ; refresh HUD each round

        LEA     COLLISION_CHOICE_MSG, A1
        BSR     PRINT_STR               ; "1=Fight  2=Run"
        BSR     READ_NUM                ; D1 = player choice

        CMP.L   #1, D1
        BEQ     .FIGHT
        CMP.L   #2, D1
        BEQ     .RUN

        LEA     ACTION_BAD_MSG, A1      ; invalid input -> re-prompt
        BSR     PRINT_STR
        BRA     .LOOP

*--- Fight ---
.FIGHT:
        CLR.B   REST_COUNTER            ; CLR.B (1 byte!) -> reset rest counter
                                        ; BUG NOTE: CLR (without .B) = CLR.W = clears 2 bytes,
                                        ; which would also zero CURRENT_MONSTER since it sits
                                        ; directly after REST_COUNTER in memory

        ; Check if current weapon has enough resources
        CMP.B   #1, WEAPON
        BEQ     .ARROW_CHECK            ; bow -> need arrows
        CMP.B   #3, WEAPON
        BEQ     .MANA_CHECK             ; staff -> need mana
        BRA     .DO_DAMAGE              ; sword -> no resource cost

.ARROW_CHECK:
        TST.B   PLAYER_ARROWS           ; any arrows left?
        BEQ     .OUT_ARROWS             ; none
        SUBQ.B  #1, PLAYER_ARROWS       ; spend 1 arrow
        BRA     .DO_DAMAGE

.OUT_ARROWS:
        LEA     OUT_OF_ARROWS_MSG, A1
        BSR     PRINT_STR
        LEA     NO_AMMO_CHOICE_MSG, A1
        BSR     PRINT_STR               ; "1=Fight barehanded  2=Run"
        BSR     READ_NUM
        CMP.L   #1, D1
        BEQ     .BARE_HANDS             ; 1 -> punch
        BRA     .RUN                    ; 2 (or invalid) -> flee

.MANA_CHECK:
        CMP.B   #20, PLAYER_MANA        ; at least 20 mana?
        BLT     .OUT_MANA               ; not enough
        SUB.B   #20, PLAYER_MANA        ; spend 20 mana
        BRA     .DO_DAMAGE

.OUT_MANA:
        LEA     OUT_OF_MANA_MSG, A1
        BSR     PRINT_STR
        LEA     NO_AMMO_CHOICE_MSG, A1
        BSR     PRINT_STR               ; "1=Fight barehanded  2=Run"
        BSR     READ_NUM
        CMP.L   #1, D1
        BEQ     .BARE_HANDS
        BRA     .RUN

*--- Barehanded punch (no ammo/mana) ---
.BARE_HANDS:
        LEA     BARE_HANDS_MSG, A1
        BSR     PRINT_STR               ; "You punch! (5 dmg)"
        MOVEQ   #5, D2                  ; fist damage = 5 (fixed, no resource cost)
        MOVEQ   #0, D1
        MOVE.B  CURRENT_MON_HP, D1
        SUB.L   D2, D1                  ; 32-bit subtract prevents byte underflow wrap
        BPL     .BH_HP_OK               ; result >= 0 -> store normally
        CLR.L   D1                      ; negative -> clamp to 0
.BH_HP_OK:
        MOVE.B  D1, CURRENT_MON_HP

        ; Monster hits back at full strength
        MOVEQ   #0, D1
        MOVE.B  BRAVERY, D1
        MOVEQ   #0, D2
        MOVE.B  CURRENT_MON_DMG, D2

        ; Special: Wizard takes 50% damage from Dragon
        CMP.B   #MON_DRAGON, CURRENT_MONSTER
        BNE     .BH_APPLY
        CMP.B   #3, PLAYER_CLASS        ; is player a Wizard?
        BNE     .BH_APPLY
        LSR.B   #1, D2                  ; halve dragon's damage

.BH_APPLY:
        SUB.L   D2, D1                  ; 32-bit subtract bravery (avoids signed byte issue)
        BPL     .BH_ALIVE               ; result >= 0 -> player survives
        CLR.L   D1                      ; negative -> dead
        MOVE.B  D1, BRAVERY
        BRA     GAME_OVER
.BH_ALIVE:
        MOVE.B  D1, BRAVERY
        BRA     .LOOP                   ; next combat round

*--- Normal weapon attack ---
.DO_DAMAGE:
        ; Player hits monster
        ; FIX: SUB.L not SUB.B -> byte subtraction wraps to 255 on underflow,
        ;      making the monster look "alive" with 255 HP instead of dying
        MOVEQ   #0, D1
        MOVE.B  CURRENT_MON_HP, D1      ; load monster HP into 32-bit register
        MOVEQ   #0, D2
        MOVE.B  PLAYER_DMG, D2          ; player damage
        SUB.L   D2, D1                  ; 32-bit subtract -> no wrap-around
        BPL     .MON_HP_OK              ; result >= 0 -> store as-is
        CLR.L   D1                      ; result < 0 -> clamp to 0 (dead next .LOOP check)
.MON_HP_OK:
        MOVE.B  D1, CURRENT_MON_HP

        ; Monster hits player
        MOVEQ   #0, D1
        MOVE.B  BRAVERY, D1             ; load bravery into 32-bit register
        MOVEQ   #0, D2
        MOVE.B  CURRENT_MON_DMG, D2     ; monster damage

        ; Special: Wizard takes 50% damage from Dragon
        CMP.B   #MON_DRAGON, CURRENT_MONSTER
        BNE     .APPLY_DMG
        CMP.B   #3, PLAYER_CLASS        ; class = 3 (Wizard)?
        BNE     .APPLY_DMG
        LSR.B   #1, D2                  ; halve dragon's damage

.APPLY_DMG:
        ; FIX: SUB.L not SUB.B -> with SUB.B + TST.B + BLE, bravery values
        ;      128-255 are interpreted as negative, triggering instant death
        SUB.L   D2, D1                  ; 32-bit: D1 = bravery - monster_dmg
        BPL     .STILL_ALIVE            ; result >= 0 -> player lives
        CLR.L   D1                      ; result < 0 -> bravery = 0
        MOVE.B  D1, BRAVERY
        BRA     GAME_OVER
.STILL_ALIVE:
        MOVE.B  D1, BRAVERY
        BRA     .LOOP                   ; next combat round

*--- Flee ---
.RUN:
        BSR     SUB_BRAVERY_FULL        ; penalty: LOSE_POINT(8) bravery lost
        SUB.B   #1, LOCATION            ; step back one position
        MOVE.B  #2, DANGER_TICK         ; fast-track next danger trigger
        RTS                             ; return to GAMEPLAY_LOOP

*--- Monster killed ---
.MONSTER_DEAD:
        ADDQ.B  #1, MONSTER_COUNTER     ; increment kill counter

        BSR     ENDL
        LEA     MON_DEAD_MSG, A1
        BSR     PRINT_STR               ; "Monster DEFEATED! (+15 bravery)"

        ; Kill bonus: +15 bravery, capped at 255
        MOVEQ   #0, D1
        MOVE.B  BRAVERY, D1
        ADD.L   #15, D1                 ; 32-bit so the CMP.L #255 below works correctly
        CMP.L   #255, D1
        BLE     .HP_OK
        MOVE.L  #255, D1
.HP_OK:
        MOVE.B  D1, BRAVERY

        BSR     ROLL_LOOT               ; roll for loot rarity -> D0

        CMP.B   #LOOT_EPIC, D0
        BEQ     .EPIC_LOOT
        CMP.B   #LOOT_LEGENDARY, D0
        BEQ     .LEGEND_LOOT

        ; No rare loot this time
        LEA     LOOT_NONE_MSG, A1
        BSR     PRINT_STR
        RTS

.EPIC_LOOT:
        BSR     GIVE_EPIC_LOOT
        RTS

.LEGEND_LOOT:
        BSR     GIVE_LEGENDARY_LOOT
        RTS

*=======================================================
* ROLL_LOOT -> determine loot rarity after a kill
*
* Input:  CURRENT_MONSTER, MONSTER_COUNTER, LOCATION
* Output: D0 = LOOT_NONE(0) / LOOT_EPIC(1) / LOOT_LEGENDARY(2)
*
* "Random" formula: roll = (MONSTER_COUNTER*3 + LOCATION) mod 8
*   Produces values 0..7; different monsters use different thresholds
*
* Drop rates (out of 8):
*   Skeleton:  1/8 legendary, 1/8 epic,  6/8 nothing
*   Orc:       2/8 legendary, 3/8 epic,  3/8 nothing
*   Giant:     2/8 legendary, 3/8 epic,  3/8 nothing
*   Dragon:    guaranteed drop (50/50 epic/legendary based on location parity)
*=======================================================
ROLL_LOOT:
        MOVEQ   #0, D0                  ; D0 = LOOT_NONE by default

        MOVEQ   #0, D1
        MOVE.B  CURRENT_MONSTER, D1     ; load monster type into D1

        ; Dragon always drops something
        CMP.B   #MON_DRAGON, D1
        BNE     .NOT_DRAG
        MOVEQ   #0, D2
        MOVE.B  LOCATION, D2
        AND.B   #1, D2                  ; check if location is even or odd
        BEQ     .GIVE_EPIC              ; even -> epic
        BRA     .GIVE_LEGEND            ; odd  -> legendary

.NOT_DRAG:
        ; Compute roll = (counter*3 + location) mod 8
        MOVEQ   #0, D2
        MOVE.B  MONSTER_COUNTER, D2     ; D2 = counter
        MOVEQ   #0, D3
        MOVE.B  D2, D3                  ; D3 = counter (copy for multiplication)
        ADD.B   D3, D2                  ; D2 = counter*2
        ADD.B   D3, D2                  ; D2 = counter*3
        MOVEQ   #0, D3
        MOVE.B  LOCATION, D3
        ADD.B   D3, D2                  ; D2 = counter*3 + location
        AND.B   #7, D2                  ; mod 8 -> value in range 0..7

        CMP.B   #MON_SKELETON, D1
        BEQ     .SKEL_CHANCE
        CMP.B   #MON_ORC, D1
        BEQ     .ORC_CHANCE
        ; Giant: roll 0-1 = legendary (2/8), 2-4 = epic (3/8), 5-7 = none (3/8)
        CMP.B   #1, D2
        BLE     .GIVE_LEGEND
        CMP.B   #4, D2
        BLE     .GIVE_EPIC
        BRA     .NO_LOOT

.SKEL_CHANCE:
        ; Skeleton: roll 0 = legendary (1/8), 1 = epic (1/8), 2-7 = none (6/8)
        CMP.B   #0, D2
        BEQ     .GIVE_LEGEND
        CMP.B   #1, D2
        BEQ     .GIVE_EPIC
        BRA     .NO_LOOT

.ORC_CHANCE:
        ; Orc: roll 0-1 = legendary (2/8), 2-4 = epic (3/8), 5-7 = none (3/8)
        CMP.B   #1, D2
        BLE     .GIVE_LEGEND
        CMP.B   #4, D2
        BLE     .GIVE_EPIC
        BRA     .NO_LOOT

.GIVE_EPIC:
        MOVE.B  #LOOT_EPIC, D0
        RTS

.GIVE_LEGEND:
        MOVE.B  #LOOT_LEGENDARY, D0
        RTS

.NO_LOOT:
        MOVE.B  #LOOT_NONE, D0
        RTS

*=======================================================
* GIVE_EPIC_LOOT -> award an epic weapon after a kill
*
* Each monster type has its own set of epic items.
* Player picks 1 of 3 weapons, or presses 0 to keep current.
* Damage values are stored in EPIC_WPN_*_DMG first,
* then written to PLAYER_DMG on selection.
*
* Items by monster:
*   Skeleton: Spectral Bow(22) / Bone Blade(18) / Soul Staff(28)
*   Orc:      Orcish Bow(25)   / Warchief Axe(20)/ Shaman Staff(32)
*   Giant:    Stone Bow(28)    / Boulder Sword(22)/ Earthstaff(35)
*   Dragon:   Dragonfang(35)   / Scale Blade(30) / Inferno Staff(42)
*=======================================================
GIVE_EPIC_LOOT:
        BSR     ENDL
        LEA     EPIC_LOOT_BANNER, A1
        BSR     PRINT_STR               ; "*** [EPIC DROP] ***"

        MOVEQ   #0, D0
        MOVE.B  CURRENT_MONSTER, D0     ; determine which item set to display

        CMP.B   #MON_SKELETON, D0
        BEQ     .SKEL_EPIC
        CMP.B   #MON_ORC, D0
        BEQ     .ORC_EPIC
        CMP.B   #MON_DRAGON, D0
        BEQ     .DRAG_EPIC
        ; Giant -> fallthrough
        LEA     EPIC_GIANT_MSG, A1
        BSR     PRINT_STR
        MOVE.B  #28, EPIC_WPN_1_DMG     ; Stone Bow
        MOVE.B  #22, EPIC_WPN_2_DMG     ; Boulder Sword
        MOVE.B  #35, EPIC_WPN_3_DMG     ; Earthstaff
        BRA     .PICK

.SKEL_EPIC:
        LEA     EPIC_SKEL_MSG, A1
        BSR     PRINT_STR
        MOVE.B  #22, EPIC_WPN_1_DMG     ; Spectral Bow
        MOVE.B  #18, EPIC_WPN_2_DMG     ; Bone Blade
        MOVE.B  #28, EPIC_WPN_3_DMG     ; Soul Staff
        BRA     .PICK

.ORC_EPIC:
        LEA     EPIC_ORC_MSG, A1
        BSR     PRINT_STR
        MOVE.B  #25, EPIC_WPN_1_DMG     ; Orcish Shortbow
        MOVE.B  #20, EPIC_WPN_2_DMG     ; Warchief Axe
        MOVE.B  #32, EPIC_WPN_3_DMG     ; Shaman Staff
        BRA     .PICK

.DRAG_EPIC:
        LEA     EPIC_DRAG_MSG, A1
        BSR     PRINT_STR
        MOVE.B  #35, EPIC_WPN_1_DMG     ; Dragonfang Bow
        MOVE.B  #30, EPIC_WPN_2_DMG     ; Scale Blade
        MOVE.B  #42, EPIC_WPN_3_DMG     ; Inferno Staff
        BRA     .PICK

.PICK:
        ; Show current weapon stats so the player can compare
        LEA     LOOT_CURRENT_MSG, A1
        BSR     PRINT_STR               ; "Your current weapon: "
        MOVEQ   #0, D1
        MOVE.B  WEAPON, D1
        BSR     PRINT_NUM               ; current weapon type number
        LEA     LOOT_CURR_DMG_MSG, A1
        BSR     PRINT_STR               ; "  DMG="
        MOVEQ   #0, D1
        MOVE.B  PLAYER_DMG, D1
        BSR     PRINT_NUM               ; current damage value
        BSR     ENDL
        LEA     LOOT_KEEP_MSG, A1
        BSR     PRINT_STR               ; "0=Keep  1/2/3=Take new weapon"

        BSR     READ_NUM
        CMP.L   #0, D1
        BEQ     .KEEP_WEAPON            ; 0 -> keep current weapon
        CMP.L   #1, D1
        BEQ     .TAKE_1
        CMP.L   #2, D1
        BEQ     .TAKE_2
        CMP.L   #3, D1
        BEQ     .TAKE_3
        BRA     .KEEP_WEAPON            ; invalid input -> keep current

.KEEP_WEAPON:
        LEA     LOOT_KEPT_MSG, A1
        BSR     PRINT_STR
        RTS

.TAKE_1:
        MOVE.B  #1, WEAPON              ; equip bow
        MOVE.B  EPIC_WPN_1_DMG, PLAYER_DMG
        LEA     TOOK_BOW_MSG, A1
        BSR     PRINT_STR
        RTS
.TAKE_2:
        MOVE.B  #2, WEAPON              ; equip sword
        MOVE.B  EPIC_WPN_2_DMG, PLAYER_DMG
        LEA     TOOK_SWORD_MSG, A1
        BSR     PRINT_STR
        RTS
.TAKE_3:
        MOVE.B  #3, WEAPON              ; equip staff
        MOVE.B  EPIC_WPN_3_DMG, PLAYER_DMG
        LEA     TOOK_STAFF_MSG, A1
        BSR     PRINT_STR
        RTS

*=======================================================
* GIVE_LEGENDARY_LOOT -> award a legendary weapon after a kill
*
* Legendary weapons have bonus effects on top of higher damage:
*   Bow   -> +5 arrows     (capped at 99)
*   Sword -> +20 bravery   (capped at 255)
*   Staff -> +30 mana      (capped at 255)
*
* Items by monster:
*   Skeleton: Shadow Longbow(32) / Deathblade(28)    / Lich Staff(38)
*   Orc:      Warlord Bow(36)    / Bloodsong Axe(30) / Hex Staff(45)
*   Giant:    Titan Bow(40)      / Golem Blade(35)   / Terran Staff(50)
*   Dragon:   Dragonheart(50)    / Dragon Fang(45)   / Dragon Soul(60)
*=======================================================
GIVE_LEGENDARY_LOOT:
        BSR     ENDL
        LEA     LEGEND_LOOT_BANNER, A1
        BSR     PRINT_STR               ; "!!! [LEGENDARY DROP] !!!"

        MOVEQ   #0, D0
        MOVE.B  CURRENT_MONSTER, D0     ; load monster type to pick item set

        CMP.B   #MON_SKELETON, D0
        BEQ     .SKEL_LEGEND
        CMP.B   #MON_ORC, D0
        BEQ     .ORC_LEGEND
        CMP.B   #MON_DRAGON, D0
        BEQ     .DRAG_LEGEND
        ; Giant
        LEA     LEGEND_GIANT_MSG, A1
        BSR     PRINT_STR
        MOVE.B  #40, LEGEND_WPN_1_DMG   ; Titan Bow
        MOVE.B  #35, LEGEND_WPN_2_DMG   ; Golem Blade
        MOVE.B  #50, LEGEND_WPN_3_DMG   ; Terran Staff
        BRA     .PICK

.SKEL_LEGEND:
        LEA     LEGEND_SKEL_MSG, A1
        BSR     PRINT_STR
        MOVE.B  #32, LEGEND_WPN_1_DMG   ; Shadow Longbow
        MOVE.B  #28, LEGEND_WPN_2_DMG   ; Deathblade
        MOVE.B  #38, LEGEND_WPN_3_DMG   ; Lich Staff
        BRA     .PICK

.ORC_LEGEND:
        LEA     LEGEND_ORC_MSG, A1
        BSR     PRINT_STR
        MOVE.B  #36, LEGEND_WPN_1_DMG   ; Warlord Bow
        MOVE.B  #30, LEGEND_WPN_2_DMG   ; Bloodsong Axe
        MOVE.B  #45, LEGEND_WPN_3_DMG   ; Hex Staff
        BRA     .PICK

.DRAG_LEGEND:
        LEA     LEGEND_DRAG_MSG, A1
        BSR     PRINT_STR
        MOVE.B  #50, LEGEND_WPN_1_DMG   ; Dragonheart Bow
        MOVE.B  #45, LEGEND_WPN_2_DMG   ; Dragon Fang Sword
        MOVE.B  #60, LEGEND_WPN_3_DMG   ; Dragon Soul Staff
        BRA     .PICK

.PICK:
        ; Show current weapon stats before choosing
        LEA     LOOT_CURRENT_MSG, A1
        BSR     PRINT_STR
        MOVEQ   #0, D1
        MOVE.B  WEAPON, D1
        BSR     PRINT_NUM               ; current weapon type
        LEA     LOOT_CURR_DMG_MSG, A1
        BSR     PRINT_STR
        MOVEQ   #0, D1
        MOVE.B  PLAYER_DMG, D1
        BSR     PRINT_NUM               ; current damage
        BSR     ENDL
        LEA     LOOT_KEEP_MSG, A1
        BSR     PRINT_STR               ; "0=Keep  1/2/3=Take new weapon"

        BSR     READ_NUM
        CMP.L   #0, D1
        BEQ     .KEEP_WEAPON            ; 0 -> keep current
        CMP.L   #1, D1
        BEQ     .TAKE_1
        CMP.L   #2, D1
        BEQ     .TAKE_2
        CMP.L   #3, D1
        BEQ     .TAKE_3
        BRA     .KEEP_WEAPON            ; invalid -> keep current

.KEEP_WEAPON:
        LEA     LOOT_KEPT_MSG, A1
        BSR     PRINT_STR
        RTS

.TAKE_1:
        MOVE.B  #1, WEAPON              ; equip legendary bow
        MOVE.B  LEGEND_WPN_1_DMG, PLAYER_DMG
        ; Legendary bow bonus: +5 arrows, capped at 99
        MOVEQ   #0, D2
        MOVE.B  PLAYER_ARROWS, D2
        ADD.B   #5, D2
        CMP.B   #99, D2
        BLE     .ARR_OK
        MOVE.B  #99, D2
.ARR_OK:
        MOVE.B  D2, PLAYER_ARROWS
        LEA     LEGEND_TOOK_BOW_MSG, A1
        BSR     PRINT_STR
        RTS

.TAKE_2:
        MOVE.B  #2, WEAPON              ; equip legendary sword
        MOVE.B  LEGEND_WPN_2_DMG, PLAYER_DMG
        ; Legendary sword bonus: +20 bravery, capped at 255
        MOVEQ   #0, D2
        MOVE.B  BRAVERY, D2
        ADD.L   #20, D2                 ; 32-bit add for safe comparison with 255
        CMP.L   #255, D2
        BLE     .BRV_OK
        MOVE.L  #255, D2
.BRV_OK:
        MOVE.B  D2, BRAVERY
        LEA     LEGEND_TOOK_SWORD_MSG, A1
        BSR     PRINT_STR
        RTS

.TAKE_3:
        MOVE.B  #3, WEAPON              ; equip legendary staff
        MOVE.B  LEGEND_WPN_3_DMG, PLAYER_DMG
        ; Legendary staff bonus: +30 mana, capped at 255
        MOVEQ   #0, D2
        MOVE.B  PLAYER_MANA, D2
        ADD.L   #30, D2
        CMP.L   #255, D2
        BLE     .MNA_OK
        MOVE.L  #255, D2
.MNA_OK:
        MOVE.B  D2, PLAYER_MANA
        LEA     LEGEND_TOOK_STAFF_MSG, A1
        BSR     PRINT_STR
        RTS

*=======================================================
* SHOW_MONSTER_HUD -> print the current combat status
*
* Prints: monster name, monster HP, monster damage, player bravery
* Called: once on entering combat, then once per round at top of .LOOP
* Side effects: none (read-only access to game state)
*=======================================================
SHOW_MONSTER_HUD:
        BSR     ENDL
        ; Select the correct monster name string
        MOVEQ   #0, D0
        MOVE.B  CURRENT_MONSTER, D0
        CMP.B   #MON_SKELETON, D0
        BEQ     .N_SKEL
        CMP.B   #MON_ORC, D0
        BEQ     .N_ORC
        CMP.B   #MON_DRAGON, D0
        BEQ     .N_DRAG
        LEA     MON_NAME_GIANT, A1      ; fallthrough = Giant
        BRA     .PRINT_NAME
.N_SKEL:
        LEA     MON_NAME_SKEL, A1
        BRA     .PRINT_NAME
.N_ORC:
        LEA     MON_NAME_ORC, A1
        BRA     .PRINT_NAME
.N_DRAG:
        LEA     MON_NAME_DRAG, A1
.PRINT_NAME:
        BSR     PRINT_STR               ; print "--- MONSTER NAME ---"

        LEA     MON_HP_MSG, A1
        BSR     PRINT_STR               ; "HP="
        MOVEQ   #0, D1
        MOVE.B  CURRENT_MON_HP, D1
        BSR     PRINT_NUM               ; monster current HP

        LEA     MON_DMG_MSG, A1
        BSR     PRINT_STR               ; "  DMG/turn="
        MOVEQ   #0, D1
        MOVE.B  CURRENT_MON_DMG, D1
        BSR     PRINT_NUM               ; monster damage per round

        BSR     ENDL
        LEA     BRAVERY_MSG, A1
        BSR     PRINT_STR               ; "  Your Bravery: "
        MOVEQ   #0, D1
        MOVE.B  BRAVERY, D1
        BSR     PRINT_NUM               ; player bravery
        BSR     ENDL
        RTS

*=======================================================
* STATUS_LINE -> player status bar displayed outside combat
*
* Prints all stats: bravery, potions, weapon, difficulty,
*                   arrows, mana, damage per hit, kills
*=======================================================
STATUS_LINE:
        BSR     ENDL
        LEA     STATUS_MSG, A1
        BSR     PRINT_STR               ; "| Bravery="
        MOVEQ   #0, D1
        MOVE.B  BRAVERY, D1
        BSR     PRINT_NUM

        LEA     STATUS_POT_MSG, A1
        BSR     PRINT_STR               ; "  BrvPot="
        MOVEQ   #0, D1
        MOVE.B  BRAVERY_POTIONS_COUNT, D1
        BSR     PRINT_NUM

        LEA     STATUS_WEP_MSG, A1
        BSR     PRINT_STR               ; "  Weapon="
        MOVEQ   #0, D1
        MOVE.B  WEAPON, D1
        BSR     PRINT_NUM

        BSR     ENDL

        LEA     STATUS_DIF_MSG, A1
        BSR     PRINT_STR               ; "  Diff="
        MOVEQ   #0, D1
        MOVE.B  DIFFICULTY, D1
        BSR     PRINT_NUM

        LEA     STATUS_ARROWS_MSG, A1
        BSR     PRINT_STR               ; "  Arrows="
        MOVEQ   #0, D1
        MOVE.B  PLAYER_ARROWS, D1
        BSR     PRINT_NUM

        LEA     STATUS_MANA_MSG, A1
        BSR     PRINT_STR               ; "  Mana="
        MOVEQ   #0, D1
        MOVE.B  PLAYER_MANA, D1
        BSR     PRINT_NUM

        LEA     STATUS_MANA_POTIONS_MSG, A1
        BSR     PRINT_STR               ; "  ManaPot="
        MOVEQ   #0, D1
        MOVE.B  MANA_POTIONS_COUNT, D1
        BSR     PRINT_NUM

        LEA     STATUS_DMG_MSG, A1
        BSR     PRINT_STR               ; "  YourDMG="
        MOVEQ   #0, D1
        MOVE.B  PLAYER_DMG, D1
        BSR     PRINT_NUM

        LEA     STATUS_KILLS_MSG, A1
        BSR     PRINT_STR               ; "  Kills="
        MOVEQ   #0, D1
        MOVE.B  MONSTER_COUNTER, D1
        BSR     PRINT_NUM

        BSR     ENDL
        RTS

*=======================================================
* BRAVERY HELPER SUBROUTINES
*=======================================================

* ADD_BRAVERY_WIN -> add WIN_POINT(2) to bravery, cap at 255
ADD_BRAVERY_WIN:
        MOVEQ   #0, D2
        MOVE.B  BRAVERY, D2
        ADD.L   #WIN_POINT, D2          ; +2 (32-bit add so CMP.L #255 works correctly)
        CMP.L   #255, D2
        BLE     .OK
        MOVE.L  #255, D2
.OK:
        MOVE.B  D2, BRAVERY
        RTS

* SUB_BRAVERY_FULL -> subtract LOSE_POINT(8) when fleeing, floor at 0
SUB_BRAVERY_FULL:
        MOVEQ   #0, D2
        MOVE.B  BRAVERY, D2
        SUB.L   #LOSE_POINT, D2         ; -8 (32-bit)
        BPL     .OK                     ; result >= 0?
        CLR.L   D2                      ; no -> clamp to 0
.OK:
        MOVE.B  D2, BRAVERY
        RTS

* SUB_BRAVERY_REDUCED -> subtract (LOSE_POINT-5)=3, floor at 0
* (reserved for future use, not currently called)
SUB_BRAVERY_REDUCED:
        MOVEQ   #0, D2
        MOVE.B  BRAVERY, D2
        SUB.L   #(LOSE_POINT-5), D2     ; -3
        BPL     .OK
        CLR.L   D2
.OK:
        MOVE.B  D2, BRAVERY
        RTS

*=======================================================
* HUD -> end-of-run summary screen
*=======================================================
HUD:
        BSR     ENDL
        LEA     HUD_MSG, A1
        BSR     PRINT_STR               ; "--- Final Stats --- Bravery="
        MOVEQ   #0, D1
        MOVE.B  BRAVERY, D1
        BSR     PRINT_NUM

        LEA     HUD_KILLS_MSG, A1
        BSR     PRINT_STR               ; "  Monsters killed="
        MOVEQ   #0, D1
        MOVE.B  MONSTER_COUNTER, D1
        BSR     PRINT_NUM

        BSR     ENDL
        RTS

*=======================================================
* REPLAY -> ask if the player wants to play again
*
* Output: D1 = entered number (0 = quit)
* NOTE: uses BRA START instead of RTS -> this re-runs
*       START which resets all state before checking D1
*=======================================================
REPLAY:
        BSR     ENDL
        LEA     REPLAY_MSG, A1
        BSR     PRINT_STR
        BSR     READ_NUM                ; D1 = player answer
        BRA     START                   ; always restart from START (which checks D1)

*=======================================================
* TRAP WRAPPERS -> thin wrappers over Easy68K TRAP #15
*=======================================================

* PRINT_STR -> print null-terminated string pointed to by A1
*   Uses TRAP #15 Task 14
PRINT_STR:
        MOVE.B  #14, D0
        TRAP    #15
        RTS

* READ_NUM -> read an integer from the keyboard, result in D1
*   Uses TRAP #15 Task 4
READ_NUM:
        MOVE.B  #4, D0
        TRAP    #15                     ; result returned in D1
        RTS

* PRINT_NUM -> print integer in D1 to the console
*   Uses TRAP #15 Task 3
PRINT_NUM:
        MOVE.B  #3, D0
        TRAP    #15
        RTS

* ENDL -> print a CR+LF newline
*   Saves and restores D0 and A1 via the stack so callers are unaffected
ENDL:
        MOVEM.L D0/A1, -(A7)            ; push D0 and A1 onto the stack
        MOVE.B  #14, D0
        LEA     CRLF, A1
        TRAP    #15
        MOVEM.L (A7)+, D0/A1            ; pop D0 and A1 back
        RTS

* CLEAR_SCREEN -> clear the simulator output window
*   Uses TRAP #15 Task 11 with parameter $FF00
CLEAR_SCREEN:
        MOVE.B  #11, D0
        MOVE.W  #$FF00, D1
        TRAP    #15
        RTS

*=======================================================
* STRING DATA (null-terminated with ,0)
*=======================================================
CRLF:               DC.B  $0D,$0A,0    ; carriage return + line feed + null terminator

WELCOME_MSG:        DC.B  '=== MINIATURE KINGDOM (TEXT QUEST) v2.0 ===',13,10
                    DC.B  'Now with: Skeleton, Orc, Giant, Dragon!',13,10
                    DC.B  'Epic and Legendary loot awaits...',13,10,0

HERO_MSG:           DC.B  'Choose hero: 1=Archer(10 arrows) 2=Knight(+20 bravery) 3=Wizard(100 mana): ',13,10,0
INVALID_HERO_MSG:   DC.B  'Invalid hero. Enter 1, 2 or 3.',13,10,0
HERO_KNIGHT_MSG:    DC.B  'KNIGHT selected. Bravery boosted to 80!',13,10,0
HERO_ARCHER_MSG:    DC.B  'ARCHER selected. You have 10 arrows!',13,10,0
HERO_WIZARD_MSG:    DC.B  'WIZARD selected. 100 mana! +2 Mana potions! Dragon deals -50% dmg to you!',13,10,0

POTIONS_MSG:        DC.B  'Enter potions (1..5): ',0
POTIONS_BAD_MSG:    DC.B  'Invalid. Try again (1..5).',13,10,0

WEAPONS_MSG:        DC.B  'Choose weapon: 1=Bow(20dmg) 2=Sword(15dmg) 3=Magic Staff(25dmg): ',0
WEAPONS_BAD_MSG:    DC.B  'Invalid weapon. Enter 1..3.',13,10,0

DIFF_MSG:           DC.B  'Choose difficulty: 1=Easy 2=Normal 3=Hard: ',0
DIFF_BAD_MSG:       DC.B  'Invalid. Enter 1..3.',13,10,0

GAMEPLAY_MSG:       DC.B  'Adventure begins! Beware the monsters...',13,10,0
STEP_MSG:           DC.B  'Moved forward. Location: ',0
SAFE_MSG:           DC.B  'Safe move! (+2 bravery)',13,10,0
SAFE_CHOICE_MSG:    DC.B  'Choose reward:',13,10
                    DC.B  '  1 = Bravery potion',13,10
                    DC.B  '  2 = 2 Arrows',13,10
                    DC.B  '  3 = Mana potion',13,10,0
GOT_ARROWS_MSG:     DC.B  'You found 2 arrows!',13,10,0
GOT_MANA_POT_MSG:   DC.B  'You found a mana potion!',13,10,0
GOT_BRV_POT_MSG:    DC.B  'You found a bravery potion!',13,10,0

; Monster intro messages (shown once per encounter)
MON_SKEL_INTRO:     DC.B  '*** A SKELETON rattles towards you! ***',13,10
                    DC.B  'Its bones glow with dark magic.',13,10,0
MON_ORC_INTRO:      DC.B  '*** An ORC charges at you! ***',13,10
                    DC.B  'It swings a rusted axe with furious rage.',13,10,0
MON_GIANT_INTRO:    DC.B  '*** A STONE GIANT blocks your path! ***',13,10
                    DC.B  'The ground shakes with each step.',13,10,0
MON_DRAG_INTRO:     DC.B  '*** A FIRE DRAGON descends from the sky! ***',13,10
                    DC.B  'Its scales are black as night, eyes burning red!',13,10,0

; Monster HUD labels (shown each combat round)
MON_NAME_SKEL:      DC.B  '--- SKELETON ---  ',0
MON_NAME_ORC:       DC.B  '--- ORC ---  ',0
MON_NAME_GIANT:     DC.B  '--- STONE GIANT ---  ',0
MON_NAME_DRAG:      DC.B  '--- FIRE DRAGON ---  ',0
MON_HP_MSG:         DC.B  'HP=',0
MON_DMG_MSG:        DC.B  '  DMG/turn=',0
MON_DEAD_MSG:       DC.B  'Monster DEFEATED! (+15 bravery)',13,10,0

COLLISION_CHOICE_MSG: DC.B '  1=Fight  2=Run',13,10,0

; Epic loot messages
EPIC_LOOT_BANNER:   DC.B  '*** [EPIC DROP] ***',13,10
                    DC.B  'The monster drops a glowing weapon!',13,10,0
EPIC_SKEL_MSG:      DC.B  'Skeleton chest opens: spectral weapons!',13,10
                    DC.B  '  1=Spectral Bow(22dmg)  2=Bone Blade(18dmg)  3=Soul Staff(28dmg)',13,10,0
EPIC_ORC_MSG:       DC.B  'Orc drops war trophies: brutal weapons!',13,10
                    DC.B  '  1=Orcish Shortbow(25dmg)  2=Warchief Axe(20dmg)  3=Shaman Staff(32dmg)',13,10,0
EPIC_GIANT_MSG:     DC.B  'Giant drops massive gear!',13,10
                    DC.B  '  1=Stone Bow(28dmg)  2=Boulder Sword(22dmg)  3=Earthstaff(35dmg)',13,10,0
EPIC_DRAG_MSG:      DC.B  'The dragon claws crack open revealing epic armaments!',13,10
                    DC.B  '  1=Dragonfang Bow(35dmg)  2=Scale Blade(30dmg)  3=Inferno Staff(42dmg)',13,10,0
TOOK_BOW_MSG:       DC.B  'You equipped the EPIC BOW!',13,10,0
TOOK_SWORD_MSG:     DC.B  'You equipped the EPIC SWORD!',13,10,0
TOOK_STAFF_MSG:     DC.B  'You equipped the EPIC STAFF!',13,10,0

; Legendary loot messages
LEGEND_LOOT_BANNER: DC.B  '!!! [LEGENDARY DROP] !!!',13,10
                    DC.B  'A legendary relic falls at your feet!',13,10,0
LEGEND_SKEL_MSG:    DC.B  'Undead relic: weapons forged in shadow!',13,10
                    DC.B  '  1=Shadow Longbow(32dmg +5arrows)  2=Deathblade(28dmg +20bravery)  3=Lich Staff(38dmg +30mana)',13,10,0
LEGEND_ORC_MSG:     DC.B  'Ancient warlord relics, stained with glory!',13,10
                    DC.B  '  1=Warlord Bow(36dmg +5arrows)  2=Bloodsong Axe(30dmg +20bravery)  3=Hex Staff(45dmg +30mana)',13,10,0
LEGEND_GIANT_MSG:   DC.B  'Titan forged weapons from the deep earth!',13,10
                    DC.B  '  1=Titan Bow(40dmg +5arrows)  2=Golem Blade(35dmg +20bravery)  3=Terran Staff(50dmg +30mana)',13,10,0
LEGEND_DRAG_MSG:    DC.B  'DRAGONHEART relics - the rarest in the realm!!!',13,10
                    DC.B  '  1=Dragonheart Bow(50dmg +5arrows)  2=Dragon Fang(45dmg +20bravery)  3=Dragon Soul(60dmg +30mana)',13,10,0
LEGEND_TOOK_BOW_MSG:   DC.B  'You equipped the LEGENDARY BOW! (+5 arrows)',13,10,0
LEGEND_TOOK_SWORD_MSG: DC.B  'You equipped the LEGENDARY SWORD! (+20 bravery)',13,10,0
LEGEND_TOOK_STAFF_MSG: DC.B  'You equipped the LEGENDARY STAFF! (+30 mana)',13,10,0

LOOT_NONE_MSG:      DC.B  'The monster drops nothing of value...',13,10,0
LOOT_CURRENT_MSG:   DC.B  'Your current weapon: ',0
LOOT_CURR_DMG_MSG:  DC.B  '  DMG=',0
LOOT_KEEP_MSG:      DC.B  '  Enter 0=Keep  1/2/3=Take new weapon',13,10,0
LOOT_KEPT_MSG:      DC.B  'You keep your current weapon.',13,10,0

; Status bar labels
STATUS_MSG:         DC.B  '| Bravery=',0
STATUS_POT_MSG:     DC.B  '  BrvPot=',0
STATUS_WEP_MSG:     DC.B  '  Weapon=',0
STATUS_DIF_MSG:     DC.B  '  Diff=',0
STATUS_ARROWS_MSG:  DC.B  '  Arrows=',0
STATUS_MANA_MSG:    DC.B  '  Mana=',0
STATUS_MANA_POTIONS_MSG: DC.B  '  ManaPot=',0
STATUS_DMG_MSG:     DC.B  '  YourDMG=',0
STATUS_KILLS_MSG:   DC.B  '  Kills=',0

; Action menu and feedback strings
ACTION_MSG:         DC.B  'Action: 1=Move  2=Rest(+5)  3=BravPotion(+10)  4=ManaPotion(+20): ',0
ACTION_BAD_MSG:     DC.B  'Invalid action.',13,10,0
REST_MSG:           DC.B  'You rest. (+5 bravery)',13,10,0
POT_USED_MSG:       DC.B  'Drank bravery potion. (+10 bravery)',13,10,0
POT_MANA_USED_MSG:  DC.B  'Drank mana potion. (+20 mana)',13,10,0
NO_POT_MSG:         DC.B  'No potions of that type left!',13,10,0

OUT_OF_ARROWS_MSG:  DC.B  'Out of arrows!',13,10,0
OUT_OF_MANA_MSG:    DC.B  'Out of mana!',13,10,0
NO_AMMO_CHOICE_MSG: DC.B  '  1=Fight barehanded(5 dmg)  2=Run',13,10,0
BARE_HANDS_MSG:     DC.B  'You punch the monster! (5 dmg)',13,10,0

BRAVERY_MSG:        DC.B  '  Your Bravery: ',0
JOURNEY_WIN_MSG:    DC.B  '=== You reached the end of the path! VICTORY! ===',13,10,0
GAME_OVER_MSG:      DC.B  '=== Bravery = 0. GAME OVER! ===',13,10,0

HUD_MSG:            DC.B  '--- Final Stats --- Bravery=',0
HUD_KILLS_MSG:      DC.B  '  Monsters killed=',0

REPLAY_MSG:         DC.B  'Enter 0 to quit, any other number to replay: ',0
BYE_MSG:            DC.B  'Farewell, brave adventurer!',13,10,0

*=======================================================
* VARIABLES (DS = Define Storage, bytes reserved but not initialised)
*
* IMPORTANT MEMORY LAYOUT NOTE:
*   REST_COUNTER and CURRENT_MONSTER are consecutive bytes.
*   Any CLR without .B (i.e. CLR.W) on REST_COUNTER would
*   corrupt CURRENT_MONSTER and cause the wrong monster name
*   to appear during combat. Always use CLR.B REST_COUNTER.
*=======================================================
DANGER_TICK:            DS.B 1  ; steps since last monster encounter (resets on trigger)
PLAYER_DMG:             DS.B 1  ; current weapon damage per hit
PLAYER_CLASS:           DS.B 1  ; 1=Archer, 2=Knight, 3=Wizard
PLAYER_MANA:            DS.B 1  ; current mana (staff costs 20 per attack)
PLAYER_ARROWS:          DS.B 1  ; current arrow count (bow costs 1 per attack)
BRAVERY:                DS.B 1  ; player health (0 = dead, max 255)
BRAVERY_POTIONS_COUNT:  DS.B 1  ; bravery potions remaining
MANA_POTIONS_COUNT:     DS.B 1  ; mana potions remaining
WEAPON:                 DS.B 1  ; equipped weapon type: 1=Bow 2=Sword 3=Staff
DIFFICULTY:             DS.B 1  ; chosen difficulty: 1=Easy 2=Normal 3=Hard
LOCATION:               DS.B 1  ; current position on the path (0..MAX_LOC)
HERO_CHOICE:            DS.L 1  ; hero selection (long, legacy -> not actively used)
GIANT_HEALTH:           DS.B 1  ; giant HP scratch (used inside COLLISION)
GIANT_HEALTH_LEFT:      DS.B 1  ; giant HP persisted between encounters
WEAPON_DMG:             DS.B 1  ; legacy scratch variable (not currently used)
GIANT_DMG:              DS.B 1  ; legacy scratch variable (not currently used)
REST_COUNTER:           DS.B 1  ; consecutive rests counter (triggers monster at 3)
                                 ; *** MUST be immediately before CURRENT_MONSTER ***

; Combat state -> set by PICK_MONSTER, used throughout COLLISION
CURRENT_MONSTER:        DS.B 1  ; active monster type (MON_SKELETON/ORC/GIANT/DRAGON)
CURRENT_MON_HP:         DS.B 1  ; active monster current HP
CURRENT_MON_DMG:        DS.B 1  ; active monster damage per round (base + difficulty bonus)
MONSTER_COUNTER:        DS.B 1  ; total monsters killed this run (shown in HUD)

; Temporary loot damage staging (set in GIVE_EPIC/LEGENDARY_LOOT before .PICK)
EPIC_WPN_1_DMG:         DS.B 1  ; damage value for epic weapon option 1 (bow)
EPIC_WPN_2_DMG:         DS.B 1  ; damage value for epic weapon option 2 (sword)
EPIC_WPN_3_DMG:         DS.B 1  ; damage value for epic weapon option 3 (staff)
LEGEND_WPN_1_DMG:       DS.B 1  ; damage value for legendary weapon option 1 (bow)
LEGEND_WPN_2_DMG:       DS.B 1  ; damage value for legendary weapon option 2 (sword)
LEGEND_WPN_3_DMG:       DS.B 1  ; damage value for legendary weapon option 3 (staff)

        END START
