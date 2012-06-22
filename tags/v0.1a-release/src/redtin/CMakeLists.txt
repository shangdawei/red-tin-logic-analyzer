#Set up include paths
INCLUDE_DIRECTORIES(
	${CMAKE_BINARY_DIR}
	${GTKMM_INCLUDE_DIRS}
)

###############################################################################
#C++ compilation
ADD_EXECUTABLE(redtin
	MainWindow.cpp
	
	main.cpp
)

###############################################################################
#Linker settings
TARGET_LINK_LIBRARIES(redtin
	m
	${GTKMM_LIBRARIES}
)

