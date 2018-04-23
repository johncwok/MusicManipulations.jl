export getfirstnotes, purgepitches!, purgepitches, twonote_distances, rm_hihatfake!

"""
    getfirstnotes(midi::MIDIFile, trackno = 2, septicks = 960)

Get only the first played note of each instrument in a series of notes.
If no note is played for `septicks` ticks, the next following notes are
considered a new series.
"""
function getfirstnotes(midi::MIDIFile, trackno = 2, septicks = 960)
    pitch = UInt8[] #save which pitches allready occurred in current series
    firstnotes = Notes() #container for firstnotes
    notes = getnotes(midi, trackno) #get all notes

    #iterate through all notes
    for (i,note) in enumerate(notes)
        #if the current note is the first of a new series, empty the pitches
        if i>1 && note.position - notes.notes[i-1].position > septicks
            pitch = UInt8[]
        end
        # take every first note of each pitch
        if !(note.value in pitch)
            push!(firstnotes.notes,note)
            push!(pitch,note.value)
        end
    end
    return firstnotes
end


"""
    purgepitches!(notes::MIDI.Notes, allowedpitch::Array{UInt8})
    purgepitches!(notes::MIDI.Notes, allowedpitch::UInt8)

Remove all notes that don\'t have a value specified in `allowedpitch`.
"""
function purgepitches!(notes::MIDI.Notes, allowedpitch::Array{UInt8})
    i = 1
    while i <= length(notes)
        if !(notes[i].value in allowedpitch)
            deleteat!(notes.notes,i)
        else
            i += 1
        end
    end
end

function purgepitches!(notes::MIDI.Notes, allowedpitch::UInt8)
    purgepitches!(notes,[allowedpitch])
end

"""
    purgepitches(notes::MIDI.Notes, allowedpitch::Array{UInt8})
    purgepitches(notes::MIDI.Notes, allowedpitch::UInt8)

Get new `Notes` without all notes that don\'t have a value specified in
`allowedpitch`.
"""
function purgepitches(notes::MIDI.Notes, allowedpitch::Array{UInt8})
    if typeof(notes.notes[1]) == MusicManipulations.MoreVelNote
        newnotes = Notes{MoreVelNote}(Vector{MoreVelNote}[],notes.tpq)
    else
        newnotes = Notes{Note}(Vector{Note}[],notes.tpq)
    end
    for note in notes
        if note.value in allowedpitch
            push!(newnotes.notes,note)
        end
    end
    return newnotes
end

function purgepitches(notes::MIDI.Notes, allowedpitch::UInt8)
    return purgepitches(notes,[allowedpitch])
end


"""
    twonote_distances(notes::MIDI.Notes, firstpitch::UInt8)

REQIRES: `notes` must contain notes of only two pitches already arranged in pairs.

Get the distances in ticks between the two notes of a pair. Specify which note
is to be considered the \"first\" note with `firstpitch`. If they occur in
different order, the distance is negative.
"""
function twonote_distances(notes::MIDI.Notes, firstpitch::UInt8)
    dist = Int[] #Array for distances

    i = 1  # index of first note of pair
    while i < length(notes) # =length(notes) covered by +1
        # decide how to take the difference between two notes
        if notes[i].value == firstpitch
            push!(dist,notes[i+1].position-notes[i].position)
        else
            # casting to prevent InexactError
            push!(dist,Int(notes[i].position)-Int(notes[i+1].position))
        end
        i += 2
    end

    return dist
end

"""
    rm_hihatfake(notes::MIDI.Notes, BACK = 100, FORW = 100, CUTOFF = 0x16)

Remove fake tip notes generated by Hihat at certain actions by spotting them and
just removing every Hihat Head event with velocity less than `CUTOFF`and position
maximum `BACK` ticks before or `FORW` ticks after foot close.
"""
function rm_hihatfake!(notes::MIDI.Notes, BACK = 100, FORW = 100, CUTOFF = 0x16)

    #first map special closed notes
    for note in notes
        if note.value == 0x16
            note.value = 0x1a
        elseif note.value == 0x2a
            note.value = 0x2e
        end
    end
    #then look for fake notes
   i = 1
   deleted = 0
   len = length(notes)
   while i <= len
      #find foot close
      if notes[i].value == 0x2c || notes[i].value == 0x1a
         #go back and remove all fake tip strokes
         j = i-1
         #search all notes in specified BACK region
         while j>0 && notes[i].position-notes[j].position < BACK
            #if they are quiet enough
            if notes[j].value == 0x2e && notes[j].velocity <= CUTOFF
               #remove them
               deleteat!(notes.notes,j)
               deleted += 1
               i-=1
               len-=1
            else
               j-=1
            end
         end
         #go forward and remove all fake tip strokes
         j=i+1
         #search all notes in specified FORW region
         while j<=len && notes[j].position-notes[i].position < FORW
            #if they are quiet enough
            if notes[j].value == 0x2e && notes[j].velocity <= CUTOFF
               #remove them
               deleteat!(notes.notes,j)
               deleted += 1
               len-=1
            else
               j+=1
            end
         end
      end
      i+=1
   end
   println("deleted $(deleted) fake notes")
end
