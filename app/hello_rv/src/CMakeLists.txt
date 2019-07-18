cmake_minimum_required(VERSION 3.0.2)

set(SRC_FILES hello_rv.c)

# change to OPTION?
IF (${RV_ENABLE_SMILE})
set(SRC_FILES hello_rv_smile.c ${SRC_FILES})
ENDIF()

add_executable(hello_rv ${SRC_FILES})

install(TARGETS hello_rv DESTINATION bin)
install(DIRECTORY include DESTINATION include/hello_rv FILES_MATCHING PATTERN "*.h")