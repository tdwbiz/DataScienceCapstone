source("./initializeSamplingString.R")

initializeChunkSampling <- function(curNumLinesToRead) {
    #------------------------------------------------------------------
    # Initializes the sampling of a file chunk
    #
    # Args:
    #   curNumLinesToRead: Integer that stores the number of lines to
    #                      read from a text file
    #
    # Returns:
    #   chunkSampling: List that stores a description of the current
    #                  file chunk sampling
    #------------------------------------------------------------------
    line_idx <- seq(1,curNumLinesToRead)
    
    chunkSampling <- list()
    
    chunkSampling$train_data_idx <- 
        which(rbinom(curNumLinesToRead,1,0.6) == 1)
    
    line_idx <- 
        line_idx[!line_idx %in% chunkSampling$train_data_idx]
    
    chunkSampling$test_data_idx <- 
        line_idx[which(rbinom(length(line_idx),1,0.5) == 1)]
    
    chunkSampling$validation_data_idx = 
        line_idx[!line_idx %in% chunkSampling$test_data_idx]    
    
    return(chunkSampling)
}

validateChunkSampling <- function(curNumLinesToRead) {
    #------------------------------------------------------------------
    # initializeChunkSampling() unit test
    #
    # Args:
    #   curNumLinesToRead: Integer that stores the number of lines to
    #                      read from a text file
    #
    # Returns:
    #   None
    #------------------------------------------------------------------
    chunkSampling <- initializeChunkSampling(curNumLinesToRead)
    
    percentSampling <- c(length(chunkSampling$train_data_idx),
                         length(chunkSampling$test_data_idx),
                         length(chunkSampling$validation_data_idx))
    
    if (sum(percentSampling) == curNumLinesToRead) {
        print('# of samples match')
    }else {
        errorobj <- simpleError('# of lines changed')
        stop(errorobj)
    }
    
    percentSampling <- percentSampling / sum(percentSampling)
    
    print(sprintf('Training data: %.2f%%', percentSampling[1]))
    print(sprintf('Test data: %.2f%%', percentSampling[2]))
    print(sprintf('Validation data: %.2f%%', percentSampling[3]))
}

sampleTextFile <- function(inputTextFilePath,
                           num_lines,
                           percentageToSample,
                           outputTextFilePath,
                           displayStatus=FALSE) {
    #--------------------------------------------------------------------
    # Generates a random sample of a text file and writes it to disk
    #
    # Args:
    #   inTextFilePath: Full path to the input text file
    #
    #   num_lines: List that stores the number of lines of each text file
    #              contained in a directory
    #
    #   percentageToSample: % of the text file to sample
    #
    #   outTextFilePath: Full path to the output text file that is a 
    #                    random sample of the input text file
    #
    #   displayStatus: Optional Boolean input that controls whether or not
    #                  text document processing status is printed to the 
    #                  status window
    #
    # Returns:
    #   sample_line_idx: Vector that stores which lines of the input
    #                    text were written to the output text file
    #--------------------------------------------------------------------
    
    # Step #1: Generate a random sampling of a text file
    #
    # Technincal Reference:
    # --------------------
    # https://class.coursera.org/dsscapstone-002/wiki/Task_1
    lines_to_read <- ceiling(10 / (percentageToSample / 100))
    
    # http://stackoverflow.com/questions/15532810/reading-40-gb-csv-file-into-r-using-bigmemory?lq=1
    # http://stackoverflow.com/questions/7260657/how-to-read-whitespace-delimited-strings-until-eof-in-r
    maxLinesToRead <- ceiling(num_lines[[basename(inputTextFilePath)]][1]/10)
    minLinesToRead <- ceiling(num_lines[[basename(inputTextFilePath)]][1]/100)
    
    if (lines_to_read > maxLinesToRead) {
        lines_to_read <- maxLinesToRead
    }else if (lines_to_read < minLinesToRead) {
        lines_to_read <- minLinesToRead
    }

    sample_line_idx <- numeric()
    file_subset <- character()
    
    if (displayStatus) {
        print("--------------------------------------------------------------")
        print(sprintf("Generating random sample of %s",
                      basename(inputTextFilePath)))        
    }

    h_conn <- file(inputTextFilePath, "r", blocking=FALSE)
    lines_read <- 0
    repeat {
        cur_chunk <- readLines(h_conn, lines_to_read, skipNul=TRUE)
        
        if (length(cur_chunk) == 0) {
            break
        }
        else {            
            cur_sample_line_idx <- which(rbinom(lines_to_read,
                                                1,
                                                percentageToSample/100) == 1)
            
            file_subset <- append(file_subset,
                                  cur_chunk[cur_sample_line_idx])
            
            sample_line_idx <- append(sample_line_idx,
                                      cur_sample_line_idx + lines_read)
            
            lines_read <- lines_read + lines_to_read
            
            if (displayStatus) {
                print(sprintf("Lines read: %d (Out of %d)",
                              lines_read,
                              num_lines[[basename(inputTextFilePath)]][1]))
            }
        }
    }
    close(h_conn)
    
    print(sprintf("Requested sampling percentage: %.5f", percentageToSample))
    
    print(sprintf("Percentage of lines sampled: %.5f",
                  100.0*length(file_subset) / 
                      num_lines[[basename(inputTextFilePath)]][1]))
    
    # Step #4: Write the random sample of a text file to disk
    h_conn <- file(outputTextFilePath, "w")
    write(file_subset, file=h_conn)
    close(h_conn)
    
    return(sample_line_idx)
}

splitTextData <- function(inputTextFilePath,
                          outputTextFileDirectory,
                          num_lines) {
    #--------------------------------------------------------------------
    # Splits a text data file into training, testing, & validation 
    # data sets (using a 60%/20%/20% split)
    #
    # Args:
    #   inTextFilePath: Full path to the input text file
    #
    #   outputTextFileDirectory: Full path to output text file directory 
    #
    #   num_lines: List that stores the number of lines of each text file
    #              contained in a directory
    #
    # Returns:
    #   None
    #--------------------------------------------------------------------
    total_num_lines <- num_lines[[basename(inputTextFilePath)]][1]
    num_lines_to_read <- ceiling(total_num_lines/100)
    
    filePrefix <- unlist(str_split(basename(inputTextFilePath),"\\.txt"))[1]
    
    trainingDataPath <- file.path(outputTextFileDirectory,
                                  paste0(filePrefix,"_TrainingData.txt"))
    
    testDataPath <- file.path(outputTextFileDirectory,
                              paste0(filePrefix,"_TestData.txt"))
    
    validationDataPath <- file.path(outputTextFileDirectory,
                                    paste0(filePrefix,"_ValidationData.txt"))
    
    h_inputConn <- file(inputTextFilePath, "r", blocking=FALSE)
    
    h_trainingDataConn <- file(trainingDataPath, "w")
    h_testDataConn <- file(testDataPath, "w")
    h_validationDataConn <- file(validationDataPath, "w")
    
    lines_read <- 0
    repeat {
        cur_chunk <- readLines(h_inputConn, num_lines_to_read, skipNul=TRUE)
        
        if (length(cur_chunk) == 0) {
            break
        }
        else {
            lines_read <- lines_read + length(cur_chunk)
            
            print("---------------------------------------------------")
            
            print(sprintf('Read %d lines (Out of %d)', lines_read,
                          total_num_lines))
            
            chunkSampling <- initializeChunkSampling(length(cur_chunk))
            
            percentSampling <- c(length(chunkSampling$train_data_idx),
                                 length(chunkSampling$test_data_idx),
                                 length(chunkSampling$validation_data_idx))
            
            percentSampling <- 100*percentSampling/sum(percentSampling)
            
            print(sprintf('Training data: %.2f%%', percentSampling[1]))
            print(sprintf('Test data: %.2f%%', percentSampling[2]))
            print(sprintf('Validation data: %.2f%%', percentSampling[3]))
            
            write(cur_chunk[chunkSampling$train_data_idx],
                  file=h_trainingDataConn)
            
            write(cur_chunk[chunkSampling$test_data_idx],
                  file=h_testDataConn)
            
            write(cur_chunk[chunkSampling$validation_data_idx],
                  file=h_validationDataConn)
        }
    }
    
    close(h_inputConn)
    close(h_trainingDataConn)
    close(h_testDataConn)
    close(h_validationDataConn)
}

splitTextDataFiles <- function(inputTextDataPath,
                               outputTextFileDirectory,
                               num_lines) {
    #--------------------------------------------------------------------
    # Splits a set of text data files into training, testing, & 
    # validation data sets (using a 60%/20%/20% split)
    #
    # Args:
    #   inputTextDataPath: Full path to a directory that stores text 
    #   data files
    #
    #   outputTextFileDirectory: Full path to output text file directory 
    #
    #   num_lines: List that stores the number of lines of each text file
    #              contained in a directory
    #
    # Returns:
    #   None
    #--------------------------------------------------------------------
    for (curTextFile in dir(inputTextDataPath, pattern=".*txt$")) {
        inputTextFilePath <- file.path(inputTextDataPath,
                                       curTextFile)
        
        splitTextData(inputTextFilePath,
                      outputTextFileDirectory,
                      num_lines)
    }
}

sampleTextFileUnitTest <- function(textFilePath,
                                   num_lines,
                                   numberOfLinesToRead,
                                   percentageToSample) {
    #--------------------------------------------------------------------
    # sampleTextFile() Unit Test
    #
    # Args:
    #   textFilePath: Full path to large text file
    #
    #   num_lines: List that stores the number of lines of each text file
    #              contained in a directory
    #
    #   numberOfLinesToRead: Number of lines to read in order to 
    #                        construct unit test input
    #
    #   percentageToSample: Percentage of lines of the unit test input to
    #                       sample
    #
    # Returns:
    #   None
    #--------------------------------------------------------------------
    
    # Step #1: Read the requested number of lines from the beginning of a
    #          large text file
    h_conn <- file(textFilePath, "r")
    doc_head <- readLines(h_conn, numberOfLinesToRead)
    close(h_conn)
    
    # Step #2: Write the large text file sample to disk
    filePrefix = strsplit(basename(textFilePath),'\\.txt')
    
    inputTextFilePath <- 
        file.path(".",paste0(filePrefix, numberOfLinesToRead, ".txt"))
    
    h_conn <- file(inputTextFilePath,"w")
    write(doc_head, file=h_conn)
    rm(doc_head)
    close(h_conn)
    
    # http://www.inside-r.org/packages/cran/R.utils/docs/countLines
    num_linesCopy <- num_lines
    h_conn <- file(inputTextFilePath, "rb")
    num_linesCopy[[basename(inputTextFilePath)]] <- countLines(h_conn)
    close(h_conn)
    
    # Step #3: Generate a random sample of a text file
    filePrefix <- strsplit(basename(inputTextFilePath),'\\.txt')
    
    outputTextFilePath <- file.path(".",paste0(filePrefix, "Sample", ".txt"))
    
    sample_line_idx <- sampleTextFile(inputTextFilePath,
                                      num_linesCopy,
                                      percentageToSample,
                                      outputTextFilePath)
    
    # Step #4: Verify that the random text file sampler is functioning 
    #          correctly
    h_conn <- file(inputTextFilePath, "r")
    inputTextFile <- scan(h_conn, what=character(), sep="\n", quiet=TRUE)
    close(h_conn)
    
    h_conn <- file(outputTextFilePath, "r")
    outputTextFile <- scan(h_conn, what=character(), sep="\n", quiet=TRUE)
    close(h_conn)
    
    for (n in seq_len(length(sample_line_idx))) {
        if (outputTextFile[n] == inputTextFile[sample_line_idx[n]]) {
            print(sprintf("line #%d matched", sample_line_idx[n]))
        }
        else {
            print("---------------------------------------------------")
            print(sprintf("Line #: %d", sample_line_idx[n]))
            print(paste("Input:", inputTextFile[sample_line_idx[n]]))
            print(paste("Output:", outputTextFile[n]))
        }
    }
}

applyRandomSamplerToTextFiles <- function(inputTextFileDirectory,
                                          percentageToSample,
                                          outputTextFileDirectory,
                                          displayStatus=FALSE) {
    #--------------------------------------------------------------------
    # Generates a random sample of each text file contained in a 
    # directory
    #
    # Args:
    #   inputTextFileDirectory: Full path to a directory that contains a 
    #                           set of text files
    #
    #   percentageToSample: Percentage of text file to randomly sample
    #
    #   outputTextFileDirectory: Full path to a directory that contains a 
    #                           random sample of a set of text files
    #
    #   displayStatus: Optional Boolean input that controls whether or not
    #                  text document processing status is printed to the 
    #                  status window
    #
    # Returns:
    #   None
    #--------------------------------------------------------------------
    load(file=file.path(outputTextFileDirectory,
                        paste0(basename(outputTextFileDirectory),
                               "NumLines.RData")))
    
    textFileSampling <- list()

    samplingStr = initializeSamplingString(percentageToSample)

    for(curTextFile in dir(inputTextFileDirectory, pattern="(.)*.txt")) {
        if (displayStatus) {
            print(sprintf("Generating a %.2f%% random sample of %s",
                          percentageToSample, curTextFile))            
        }

        curOutputFileName <- 
            paste0(strsplit(curTextFile,"\\.txt"),samplingStr,".txt")
    
        textFileSampling[[curOutputFileName]] <- 
            sampleTextFile(file.path(inputTextFileDirectory,
                                     curTextFile),
                           num_lines,
                           percentageToSample,
                           file.path(outputTextFileDirectory,
                                     curOutputFileName),
                           displayStatus)
    }
    save(file=file.path(outputTextFileDirectory,
                        paste0(basename(inputTextFileDirectory),
                               samplingStr,'Sampling.RData')),
         textFileSampling)
}
