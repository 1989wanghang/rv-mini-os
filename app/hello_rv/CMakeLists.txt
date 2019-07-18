cmake_minimum_required(VERSION 3.0.2)

#get RV_ENABLE_SMILE from hello_rv.rvmk: HELLO_RV_CONF_OPTS = -DRV_ENABLE_SMILE=...
if (DEFINED RV_ENABLE_SMILE)
# transfer the macro value to source code
  add_definitions(-DENABLE_SMILE=${RV_ENABLE_SMILE})
endif()

add_subdirectory(src)