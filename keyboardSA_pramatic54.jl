# ### SETUP ###
# ~~~ libraries ~~~
import Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()
using Plots
using Random, StableRNGs
using Base.Threads
using BenchmarkTools
using Statistics


# ~~~ rng ~~~
seed = 123456
const rng = StableRNGs.LehmerRNG(seed)

# ~~~ data ~~~
bookPath = "myData.txt"

# ~~~ weights ~~~
const distanceEffort = 1 # at 2 distance penalty is squared
const doubleFingerEffort = 1
const doubleHandEffort = 1

const fingerCPM = [248, 312, 300, 324, 336, 336, 324, 300, 312, 248] # how many clicks can you do in a minute
meanCPM = mean(fingerCPM)
stdCPM = std(fingerCPM)
zScoreCPM = -(fingerCPM .- meanCPM) ./ stdCPM # negative since higher is better
const fingerEffort = zScoreCPM .- minimum(zScoreCPM)

const rowCPM = [228, 240, 324, 300, 300]
meanCPM = mean(rowCPM)
stdCPM = std(rowCPM)
zScoreCPM = -(rowCPM .- meanCPM) ./ stdCPM # negative since higher is better
const rowEffort = zScoreCPM .- minimum(zScoreCPM)

const effortWeighting = (0.8, 1, 0, 0.5, 0.00) # dist, finger, row. Also had room for other weightings but removed for simplicity

# ~~~ keyboard ~~~
# pragmatic (x, y, row, finger, home)
pragmaticLayoutMap = Dict{Int, Tuple{Float64, Float64, Int, Int, Int}}(
    # Left Hand 1st Row (x, y, row, finger, home)
    1 =>  (1 + 1,       1 + 5,      1, 1, 0),
    2 =>  (1 + 2,       1 + 5.35,   1, 2, 0),
    3 =>  (1 + 3,       1 + 5.5,    1, 3, 0),
    4 =>  (1 + 4,       1 + 5.35,   1, 4, 0),
    5 =>  (1 + 5,       1 + 5.2,    1, 4, 0),

    # Right Hand 1nd Row (x, y, row, finger, home)
    6 =>  (1 + 10,      1 + 5.2,    1, 7, 0),
    7 =>  (1 + 11,      1 + 5.35,   1, 7, 0),
    8 =>  (1 + 12,      1 + 5.5,    1, 8, 0),
    9 =>  (1 + 13,      1 + 5.35,   1, 9, 0),
    10 => (1 + 14,      1 + 5,      1, 10, 0),

    # Left Hand 2nd Row (x, y, row, finger, home)
    11 => (1 + 1,       1 + 4,      2, 1, 0),
    12 => (1 + 2,       1 + 4.35,   2, 2, 0),
    13 => (1 + 3,       1 + 4.5,    2, 3, 0),
    14 => (1 + 4,       1 + 4.35,   2, 4, 0),
    15 => (1 + 5,       1 + 4.2,    2, 4, 0),

    # Right Hand 2nd Row (x, y, row, finger, home)
    16 => (1 + 10,      1 + 4.2,    2, 7, 0),
    17 => (1 + 11,      1 + 4.35,   2, 7, 0),
    18 => (1 + 12,      1 + 4.5,    2, 8, 0),
    19 => (1 + 13,      1 + 4.35,   2, 9, 0),
    20 => (1 + 14,      1 + 4,      2, 10, 0),

    # Left Hand 3rd Row (HOME) (x, y, row, finger, home)
    21 => (1 + 1,       1 + 3,      3, 1, 1),
    22 => (1 + 2,       1 + 3.35,   3, 2, 1),
    23 => (1 + 3,       1 + 3.5,    3, 3, 1),
    24 => (1 + 4,       1 + 3.35,   3, 4, 1),
    25 => (1 + 5,       1 + 3.2,    3, 4, 1),

    # Right Hand 3rd Row (HOME) (x, y, row, finger, home)
    26 => (1 + 10,      1 + 3.2,    3, 7, 1),
    27 => (1 + 11,      1 + 3.35,   3, 7, 1),
    28 => (1 + 12,      1 + 3.5,    3, 8, 1),
    29 => (1 + 13,      1 + 3.35,   3, 9, 1),
    30 => (1 + 14,      1 + 3,      3, 10, 1),

    # Left Hand 4th Row (x, y, row, finger, home)
    31 => (1 + 1,       1 + 2,      4, 1, 0),
    32 => (1 + 2,       1 + 2.35,   4, 2, 0),
    33 => (1 + 3,       1 + 2.5,    4, 3, 0),
    34 => (1 + 4,       1 + 2.35,   4, 4, 0),
    35 => (1 + 5,       1 + 2.2,    4, 4, 0),

    # Right Hand 4th Row (x, y, row, finger, home)
    36 => (1 + 10,      1 + 2.2,    4, 7, 0),
    37 => (1 + 11,      1 + 2.35,   4, 7, 0),
    38 => (1 + 12,      1 + 2.5,    4, 8, 0),
    39 => (1 + 13,      1 + 2.35,   4, 9, 0),
    40 => (1 + 14,      1 + 2,      4, 10, 0),

    # Left Hand Thumb Row (x, y, row, finger, home)
    41 => (1 + 3.5,     1 + 1,      5, 5, 0),
    42 => (1 + 4.5,     1 + 1,      5, 5, 0),
    43 => (1 + 5.5,     1 + 1,      5, 5, 0),

    # Right Hand Thumb Row (x, y, row, finger, home)
    44 => (1 + 9.5,     1 + 1,      5, 6, 0),
    45 => (1 + 10.5,    1 + 1,      5, 6, 0),
    46 => (1 + 11.5,    1 + 1,      5, 6, 0),

    # Left Hand Outer Column (x, y, row, finger, home)
    47 => (1 + 0,       1 + 4.8,    1, 1, 0),
    48 => (1 + 0,       1 + 3.8,    2, 1, 0),
    49 => (1 + 0,       1 + 2.8,    3, 1, 0),
    50 => (1 + 0,       1 + 1.8,    4, 1, 0),

    # Right Hand Outer Column (x, y, row, finger, home)
    51 => (1 + 15,      1 + 4.8,     1, 10, 0),
    52 => (1 + 15,      1 + 3.8,     2, 10, 0),
    53 => (1 + 15,      1 + 2.8,     3, 10, 0),
    54 => (1 + 15,      1 + 1.8,     4, 10, 0),
)

# comparisons
QWERTYgenome = [
    '~','1','2','3','4','5','6','7','8','9','0','-','+',
    'Q','W','E','R','T','Y','U','I','O','P','[',']',
    'A','S','D','F','G','H','J','K','L',';',''',
    'Z','X','C','V','B','N','M','<','>','?',
    "F1","F2","F3","F4","F5","F6","F7","F8",
]

PRAGMATICgenome = [
    '1','2','3','4','5','6','7','8','9','0',
    'Q','W','E','R','T','Y','U','I','O','P',
    'A','S','D','F','G','H','J','K','L',';',
    'Z','X','C','V','B','N','M','<','>','?',
    '-','+','[',']',''','~',
    "F1","F2","F3","F4","F5","F6","F7","F8",
]

# alphabet
const letterList = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
    '0','1','2','3','4','5','6','7','8','9','~','-','+',
    '[',']',';',''','<','>','?',
    "F1","F2","F3","F4","F5","F6","F7","F8",
]

# map dictionary
const keyMapDict = Dict(
    'a' => [1,0], 'A' => [1,1], 'b' => [2,0], 'B' => [2,1],
    'c' => [3,0], 'C' => [3,1], 'd' => [4,0], 'D' => [4,1],
    'e' => [5,0], 'E' => [5,1], 'f' => [6,0], 'F' => [6,1],
    'g' => [7,0], 'G' => [7,1], 'h' => [8,0], 'H' => [8,1],
    'i' => [9,0], 'I' => [9,1], 'j' => [10,0], 'J' => [10,1],
    'k' => [11,0], 'K' => [11,1], 'l' => [12,0], 'L' => [12,1],
    'm' => [13,0], 'M' => [13,1], 'n' => [14,0], 'N' => [14,1],
    'o' => [15,0], 'O' => [15,1], 'p' => [16,0], 'P' => [16,1],
    'q' => [17,0], 'Q' => [17,1], 'r' => [18,0], 'R' => [18,1],
    's' => [19,0], 'S' => [19,1], 't' => [20,0], 'T' => [20,1],
    'u' => [21,0], 'U' => [21,1], 'v' => [22,0], 'V' => [22,1],
    'w' => [23,0], 'W' => [23,1], 'x' => [24,0], 'X' => [24,1],
    'y' => [25,0], 'Y' => [25,1], 'z' => [26,0], 'Z' => [26,1],
    '0' => [27,0], ')' => [27,1], '1' => [28,0], '!' => [28,1],
    '2' => [29,0], '@' => [29,1], '3' => [30,0], '#' => [30,1],
    '4' => [31,0], '$' => [31,1], '5' => [32,0], '%' => [32,1],
    '6' => [33,0], '^' => [33,1], '7' => [34,0], '&' => [34,1],
    '8' => [35,0], '*' => [35,1], '9' => [36,0], '(' => [36,1],
    '`' => [37,0], '~' => [37,1], '-' => [38,0], '_' => [38,1],
    '=' => [39,0], '+' => [39,1], '[' => [40,0], '{' => [40,1],
    ']' => [41,0], '}' => [41,1], ';' => [42,0], ':' => [42,1],
    ''' => [43,0], '"' => [43,1], ',' => [44,0], '<' => [44,1],
    '.' => [45,0], '>' => [45,1], '/' => [46,0], '?' => [46,1],
    "F1" => [47,0], "F2" => [48,0], "F3" => [49,0], "F4" => [50,0],
    "F5" => [51,0], "F6" => [52,0], "F7" => [53,0], "F8" => [54,0],
)

const handList = [1, 1, 1, 1, 1, 2, 2, 2, 2, 2] # what finger is with which hand

# ### KEYBOARD FUNCTIONS ###
function createGenome()
    # setup
    myGenome = shuffle(rng, letterList)

    # return
    return myGenome
end

function drawKeyboard(myGenome, id, currentLayoutMap)
    plot()
    defaultColor = "gray69"
    # https://juliagraphics.github.io/Colors.jl/stable/namedcolors/

    for i in 1:length(myGenome)
        letter = myGenome[i]
        x, y, row, finger, home = currentLayoutMap[i]

        myColor = defaultColor

        if letter in ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';',]
            myColor = "darkgreen" 

        elseif letter in ['1','2','3','4','5','6','7','8','9','0',]
            myColor = "orange" 

        elseif letter in ['-','+','[',']',''','~','<','>','?',]
           myColor = "tomato" 

        elseif letter in ["F1","F2","F3","F4","F5","F6","F7","F8",]
            myColor = "midnightblue" 
        end

        if home == 1.0
            plot!(
                [x], [y],
                shape=:rect, 
                markersize= 15, 
                linecolor=nothing, 
                fillalpha=0.2, color = myColor, label ="", dpi = 100)
        end
        
        plot!(
            [x - 0.45, x + 0.45, x + 0.45, x - 0.45, x - 0.45], 
            [y - 0.45, y - 0.45, y + 0.45, y + 0.45, y - 0.45], 
            fillalpha=0.2, color = myColor, label ="", dpi = 100)
        
        annotate!(x, y, text(letter, :black, :center, 10))

    end
    
    plot!(aspect_ratio = 1, legend = false)
    savefig("$id.png")

end

function countCharacters(bookPath::String = "myData.txt", outputPath::String = "countCharacters.txt")
    # Dictionary to store counts of characters, spaces, and numbers
    char_count = Dict{String, Int}()

    # Open the file using a context manager
    open(bookPath, "r") do io
        for line in eachline(io)
            for char in line
                char = uppercase(char)
                
                if isletter(char)
                    # Use string() to convert Char to String
                    key = string(char)
                    char_count[key] = get(char_count, key, 0) + 1
                elseif isdigit(char)
                    # Count numeric digits
                    key = "DIGIT_$char"
                    char_count[key] = get(char_count, key, 0) + 1
                elseif char == ' '
                    # Count spaces
                    char_count["SPACE"] = get(char_count, "SPACE", 0) + 1
                end
            end
        end
    end

    # Sort the dictionary by counts (largest to smallest)
    sorted_counts = sort(collect(char_count), by = x -> x[2], rev = true)

    # Write the counts to the output file
    open(outputPath, "w") do io
        for (key, count) in sorted_counts
            write(io, "$key: $count\n")
        end
    end

    println("Character counts written to $outputPath")
end





# ### SAVE SCORE ###
function appendUpdates(updateLine)
    file = open("iterationScores.txt", "a")
    write(file, updateLine, "\n")
    close(file)
end

# ### OBJECTIVE FUNCTIONS ###
function determineKeypress(currentCharacter)
    # setup
    keyPress = nothing

    # proceed if valid key (e.g. we dont't care about spaces now)
    if haskey(keyMapDict, currentCharacter)
        keyPress, _ = keyMapDict[currentCharacter]
    end

    # return
    return keyPress
end

function doKeypress(myFingerList, myGenome, keyPress, oldFinger, oldHand, currentLayoutMap)
    # setup
    # ~ get the key being pressed ~
    namedKey = letterList[keyPress]
    actualKey = findfirst(x -> x == namedKey, myGenome)

    # ~ get its location ~
    x, y, row, finger, home = currentLayoutMap[actualKey]
    currentHand = handList[finger]

    # loop through fingers
    for fingerID in 1:length(handList)
        # load
        homeX, homeY, currentX, currentY, distanceCounter, objectiveCounter = ntuple(i -> myFingerList[fingerID, i], Val(6))

        if fingerID == finger # move finger to key and include penalty
            # ~ distance
            distance = sqrt((x - currentX)^2 + (y - currentY)^2)

            distancePenalty = distance^distanceEffort # i.e. squared
            newDistance = distanceCounter + distance

            # ~ double finger ~
            doubleFingerPenalty = 0
            if finger != oldFinger && oldFinger != 0 && distance != 0
                doubleFingerPenalty = doubleFingerEffort
            end
            oldFinger = finger


            # ~ double hand ~
            doubleHandPenalty = 0
            if currentHand != oldHand && oldHand != 0
                doubleHandPenalty = doubleHandEffort
            end
            oldHand = currentHand

            # ~ finger
            fingerPenalty = fingerEffort[fingerID]

            # ~ row
            rowPenalty = rowEffort[row]

            # ~ combined weighting
            penalties = (distancePenalty, doubleFingerPenalty, doubleHandPenalty, fingerPenalty, rowPenalty)
            penalty = sum(penalties .* effortWeighting)
            newObjective = objectiveCounter + penalty

            # ~ save
            myFingerList[fingerID, 3] = x
            myFingerList[fingerID, 4] = y
            myFingerList[fingerID, 5] = newDistance
            myFingerList[fingerID, 6] = newObjective
        else # re-home unused finger
            myFingerList[fingerID, 3] = homeX
            myFingerList[fingerID, 4] = homeY
        end
    end

    # return
    return myFingerList, oldFinger, oldHand
end

function objectiveFunction(file, myGenome, currentLayoutMap)
    # setup
    objective = 0

    # ~ create hand ~
    myFingerList = zeros(length(handList), 6) # (homeX, homeY, currentX, currentY, distanceCounter, objectiveCounter)

    for i in 1:46
        x, y, _, finger, home = currentLayoutMap[i]

        if home == 1.0
            myFingerList[finger, 1:4] = [x, y, x, y]
        end
    end

    # load text
    oldFinger = 0
    oldHand = 0

    for currentCharacter in file
        # determine keypress
        keyPress = determineKeypress(currentCharacter)

        # do keypress
        if keyPress !== nothing
            myFingerList, oldFinger, oldHand = doKeypress(myFingerList, myGenome, keyPress, oldFinger, oldHand,
                currentLayoutMap)
        end
    end

    # calculate objective
    objective = sum(myFingerList[:, 6])
    objective = (objective / QWERTYscore - 1) * 100

    # return
    return objective
end

function baselineObjectiveFunction(file, myGenome, currentLayoutMap) # same as previous but for getting QWERTY baseline
    # setup
    objective = 0

    # ~ create hand ~
    myFingerList = zeros(length(handList), 6) # (homeX, homeY, currentX, currentY, distanceCounter, objectiveCounter)

    for i in 1:46
        x, y, _, finger, home = currentLayoutMap[i]

        if home == 1.0
            myFingerList[finger, 1:4] = [x, y, x, y]
        end
    end

    oldFinger = 0
    oldHand = 0

    for currentCharacter in file
        # determine keypress
        keyPress = determineKeypress(currentCharacter)

        # do keypress
        if keyPress !== nothing
            myFingerList, oldFinger, oldHand = doKeypress(myFingerList, myGenome, keyPress, oldFinger, oldHand,
                currentLayoutMap)
        end
    end

    # calculate objective
    objective = sum(myFingerList[:, 6])
    objective = objective

    # return
    return objective
end

# ### SA OPTIMISER ###
function shuffleGenome(currentGenome, temperature)
    # setup
    noSwitches = Int(maximum([2, minimum([floor(temperature / 100), length(currentGenome)])]))

    # positions of switched letterList
    switchedPositions = randperm(rng, length(currentGenome))[1:noSwitches]
    newPositions = shuffle(rng, copy(switchedPositions))

    # create new genome by shuffeling
    newGenome = copy(currentGenome)
    for i in 1:noSwitches
        og = switchedPositions[i]
        ne = newPositions[i]

        newGenome[og] = currentGenome[ne]
    end

    # return
    return newGenome

end


function runSA(
    layoutMap=pragmaticLayoutMap;
    baselineLayout=QWERTYgenome,
    temperature=500,
    epoch=20,
    coolingRate=0.99,
    num_iterations=25000,
    save_current_best=:plot,
    verbose=true,
)
    currentLayoutMap = layoutMap
    file = open(io -> read(io, String), bookPath, "r")
    countCharacters()

    verbose && println("Running code...")
    verbose && print("Calculating raw baseline: ")
    global QWERTYscore = baselineObjectiveFunction(file, baselineLayout, currentLayoutMap) # yes its a global, fight me
    verbose && println(QWERTYscore)
    verbose && println("From here everything is reletive with + % worse and - % better than this baseline \n Note that best layout is being saved as a png at each step. Kill program when satisfied.")
    verbose && println("Temperature \t Best Score \t New Score")


    # setup
    currentGenome = createGenome()
    currentObjective = objectiveFunction(file, currentGenome, currentLayoutMap)

    bestGenome = currentGenome
    bestObjective = currentObjective

    drawKeyboard(PRAGMATICgenome, 0, currentLayoutMap)
    drawKeyboard(bestGenome, 1, currentLayoutMap)

    # run SA
    staticCount = 0.0
    iteration = 0
    while iteration <= num_iterations && temperature > 1.0
        iteration += 1
        # ~ create new genome ~
        newGenome = shuffleGenome(currentGenome, 2)

        # ~ asess ~
        newObjective = objectiveFunction(file, newGenome, currentLayoutMap)
        delta = newObjective - currentObjective

        # verbose && println(round(temperature, digits=2), "\t", round(bestObjective, digits=2), "\t", round(newObjective, digits=2))

        if delta < 0
            currentGenome = copy(newGenome)
            currentObjective = newObjective

            updateLine = string(round(temperature, digits=2), ", ", iteration, ", ", round(bestObjective, digits=5), ", ", round(newObjective, digits=5))
            appendUpdates(updateLine)

            # if newObjective < bestObjective
            #     bestGenome = newGenome
            #     bestObjective = newObjective

            #     if save_current_best === :plot
            #         verbose && println("(new best, png being saved)")
            #         drawKeyboard(bestGenome, iteration, currentLayoutMap)
            #     else
            #         verbose && println("(new best, text being saved)")
            #         open("bestGenomes.txt", "a") do io
            #             print(io, iteration, ":")
            #             for c in bestGenome
            #                 print(io, c)
            #             end
            #             println(io)
            #         end
            #     end
            # end
        elseif exp(-delta / temperature) > rand(rng)
            currentGenome = newGenome
            currentObjective = newObjective
        end

        staticCount += 1.0

        if staticCount > epoch
            staticCount = 0.0
            temperature = temperature * coolingRate

            if rand(rng) < 0.5
                currentGenome = bestGenome
                currentObjective = bestObjective
            end
        end
    end

    # save
    drawKeyboard(bestGenome, "final", currentLayoutMap)

    # return
    return bestGenome

end


# ### RUN ###
Random.seed!(rng, seed)
@time runSA()
