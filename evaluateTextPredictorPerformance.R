source("./constructTransitionMatrix.R")
source("./shinyApplication/predictNextWord.R")

applyPredictorToTextFile <- function(predictorEvalParams,
                                     textDataFile,
                                     textFileLanguage = "english",
                                     numberCores=1) {
    #----------------------------------------------------------------------
    # Evaluates the performance of a Markov-chain model to predict the
    # next word of a phrase
    #
    # Args:
    #   predictorEvalParams: List that contains the following parameters:
    #       - textFileDirectory: String that defines the directory where
    #                            the input text file is located
    #
    #       - num_lines: List that stores the number of lines for training,
    #                    testing, & validation data sets
    #
    #       - blackList: Character vector that stores a list of profane
    #                    words to remove
    #
    #       - textPredictor: markovchain class object that is used to predict 
    #                        the next word in a phrase
    #
    #   textFileLanguage: Optional input that defines the language to 
    #                     generate prediction results for
    #
    #   numberCores: Optional input that defines the number of cores that
    #                is used by the tm package
    #----------------------------------------------------------------------
    

    #http://stackoverflow.com/questions/24099098/language-detection-
    #   in-r-with-the-textcat-package-how-to-restrict-to-a-few-lang
    profileDb <- TC_byte_profiles[names(TC_byte_profiles) %in% 
                                      c("english",
                                        "french",
                                        "finnish",
                                        "russian-iso8859_5",
                                        "russian-koi8_r",
                                        "russian-windows1251")]
    
    inputTextFilePath <- file.path(predictorEvalParams[["textFileDirectory"]],
                                   textDataFile)
    
    total_num_lines <- predictorEvalParams[["num_lines"]][[textDataFile]][1]
    num_lines_to_read <- 2500
    
    lines_read <- 0
    h_conn <- file(inputTextFilePath, "r", blocking=FALSE)
    
    print("---------------------------------------------------------")
    print(sprintf("Analyzing %s", textDataFile))
    
    textFileEval <- list()
    textFileEval[["trigramCount"]] <- 0
    textFileEval[["commonTrigramCount"]] <- 0
    textFileEval[["numCorrectPredictions"]] <- 0
    textFileEval[["incorrectPredictions"]] <- character()
    
    resultsFilePrefix <- unlist(str_split(textDataFile,"\\.txt"))[1]
    
    repeat {
        cur_chunk <- readLines(h_conn, num_lines_to_read, skipNul=TRUE)
        
        if (length(cur_chunk) > 0) {
            lines_read <- lines_read + length(cur_chunk)
            
            print("---------------------------------------------------------")
            print(sprintf("Lines read: %d (Out of %d)", lines_read,
                          total_num_lines))
            
            # http://stackoverflow.com/questions/9546109/how-to-
            #   remove-002-char-in-ruby
            #
            # http://stackoverflow.com/questions/11874234/difference-between-w-
            #   and-b-regular-expression-meta-characters
            cur_chunk <- gsub("\\W+"," ", cur_chunk)
                
            curChunkLanguage <- textcat(cur_chunk, p = profileDb)   
                
            validLanguageIdx <- 
                which(grepl(paste0(textFileLanguage,"[a-z0-9_]*"),
                            curChunkLanguage))
            
            cur_chunk <- cur_chunk[validLanguageIdx]
            
            if (length(cur_chunk) == 0) {
                break
            }
            else {
                curChunkEval <- evaluateCurrentChunk(cur_chunk,
                                                     predictorEvalParams,
                                                     numberCores)
                
                textFileEval[["trigramCount"]] <-
                    textFileEval[["trigramCount"]] + 
                    curChunkEval[["trigramCount"]]
                    
                textFileEval[["commonTrigramCount"]] <-
                    textFileEval[["commonTrigramCount"]] + 
                    curChunkEval[["commonTrigramCount"]]
                
                textFileEval[["numCorrectPredictions"]] <-
                    textFileEval[["numCorrectPredictions"]] + 
                    curChunkEval[["numCorrectPredictions"]]
                    
                textFileEval[["incorrectPredictions"]] <-
                    append(textFileEval[["incorrectPredictions"]],
                           curChunkEval[["incorrectPredictions"]])
                
                save(file=file.path(predictorEvalParams[["textFileDirectory"]],
                                    paste0(resultsFilePrefix, "Eval.RData")),
                     textFileEval)
            }
        } else {
            break
        }
    }
    close(h_conn)
    
    return(textFileEval)
}

evaluateCurrentChunk <- function(cur_chunk,
                                 predictorEvalParams,
                                 numberCores=1) {
    #----------------------------------------------------------------------
    # Evaluates the performance of a text predictor for a subset of an
    # input text file
    #
    # Args:
    #   cur_chunk: Character vector that stores a subset of an input text 
    #              file
    #
    #   predictorEvalParams: List that contains the following parameters:
    #       - textFileDirectory: String that defines the directory where
    #                            the input text file is located
    #
    #       - num_lines: List that stores the number of lines for training,
    #                    testing, & validation data sets
    #
    #       - blackList: Character vector that stores a list of profane
    #                    words to remove
    #
    #       - textPredictor: markovchain class object that is used to predict 
    #                        the next word in a phrase
    #
    #   numberCores: Optional input that defines the number of cores that
    #                is used by the tm package
    #----------------------------------------------------------------------
    tdmTri <- tokenizeTrigrams(cur_chunk,
                               predictorEvalParams[["blackList"]],
                               numberCores)

    curChunkEval <- list()
    curChunkEval[["trigramCount"]] <- length(tdmTri)

    commonTerms <- predictorEvalParams[["textPredictor"]]@states

    commonIdx <- initializeCommonTrigramIndices(tdmTri, commonTerms)
    
    curChunkEval[["commonTrigramCount"]] <- length(commonIdx)
    
    trigrams <- names(tdmTri[commonIdx])

    curChunkEval[["numCorrectPredictions"]] <- 0
    curChunkEval[["incorrectPredictions"]] <- character()
    
    for (triIdx in seq_len(length(trigrams))) {
        if (triIdx %% 1000 == 0) {
            print(sprintf("    Processing trigram #%d (out of %d)",
                          triIdx, length(trigrams)))
        }
        
        currentPhrase <-
            preprocessTextInput(trigrams[triIdx],
                                predictorEvalParams[["blackList"]])
    
        textPrediction <-
            predictNextWord(currentPhrase[1:2],
                            3,
                            predictorEvalParams[["textPredictor"]])
        
        if (currentPhrase[3] %in% 
            names(textPrediction$conditionalProbability)) {
            curChunkEval[["numCorrectPredictions"]] <-
                curChunkEval[["numCorrectPredictions"]] + 1
        } else {
            curChunkEval[["incorrectPredictions"]] <- 
                append(curChunkEval[["incorrectPredictions"]],
                       trigrams[triIdx])
        }
    }
    
    return(curChunkEval)
}

evaluateTextPredictorPerformance <- function(predictorEvalParams,
                                             textFilePattern,
                                             textFileLanguage = "english",
                                             numberCores=1) {
    #----------------------------------------------------------------------
    # Evaluates a text predictor's performance for a set of text files
    # stored in a directory
    #
    # Args:
    #   predictorEvalParams: List that contains the following parameters:
    #       - textFileDirectory: String that defines the directory where
    #                            the input text file is located
    #
    #       - num_lines: List that stores the number of lines for training,
    #                    testing, & validation data sets
    #
    #       - blackList: Character vector that stores a list of profane
    #                    words to remove
    #
    #       - textPredictor: markovchain class object that is used to predict 
    #                        the next word in a phrase
    #
    #   textFilePattern: String that defines a regular expression that is
    #                    used to select a set of files located in a 
    #                    directory
    #
    #   textFileLanguage: Optional input that defines the language to 
    #                     generate prediction results for
    #
    #   numberCores: Optional input that defines the number of cores that
    #                is used by the tm package
    #----------------------------------------------------------------------
    predictorEval <- list()
    
    for (curTextFile in dir(predictorEvalParams[["textFileDirectory"]],
                            pattern=textFilePattern)) {
        curFieldName <- unlist(str_split(curTextFile,"\\.txt"))[1]
        
        predictorEval[[curFieldName]] <- 
            applyPredictorToTextFile(predictorEvalParams,
                                     curTextFile,
                                     textFileLanguage,
                                     numberCores)
    }
    
    return(predictorEval)
}
