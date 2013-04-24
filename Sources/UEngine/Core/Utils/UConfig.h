#pragma once
#include "..\Basic\USingleton.hpp"
#include "..\Resources\uxmlfile.h"

// Load parameters from the configuration file
class UConfig :	public USingleton<UConfig>{

	static const string UCONFIG_FILE_PATH;
	UXMLFile uCfg;
	UConfig();

public:
	
	static UConfig* GetInstance(); 
	std::string GetParam(std::string param_path);

	~UConfig();	
};

// Singleton
//UConfig* UConfig::instance = NULL;