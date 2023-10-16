macro "Analisar imagens de CD31" {
	
	
	arquivos = newArray(0);
	dir = getDirectory("Escolha uma Pasta com as imagens .lif");
	
	list = getFileList(dir);
	for(i = 0; i < list.length; i++) {
		
		if (list[i].contains("MOCK")) {
		
			if(endsWith(list[i], ".lif")) {
			arquivos = Array.concat(arquivos,list[i]);
			}
		}
			
		if (list[i].contains("USUV")) {
		
			if(endsWith(list[i], ".lif")) {
			arquivos = Array.concat(arquivos,list[i]);
			}	
		}

	}
	Array.print(arquivos);

	for(arq = 0; arq < arquivos.length; arq++) { //loop por todos os arquivos da pasta
		
		//print("\\Clear");
		print(arquivos[arq]);
		file = dir + arquivos[arq];	
		print(arq, file);		
		
		print("Directory: ",dir);
		outputdir = "fiji_outputs"; // NOME DO DIRETORIO DE DESTINO
		File.makeDirectory(dir+outputdir);
		
		if (!File.exists(dir+outputdir)) {
		      exit("Unable to create directory");
		}
		print("destino: "+dir+outputdir);
				
		run("Bio-Formats Macro Extensions");
		Ext.setId(file);

		Ext.getFormat(file, format);
		print("formato do dado: ", format);
		Ext.getSeriesCount(seriesCount);
		print("NUMERO DE DATASETS: ",seriesCount);
		//Ext.getUsedFileCount(count);//Gets the number of files that are part of this dataset.
		//print(count);
		Ext.getCurrentFile(fl);//Gets the base filename used to initialize this dataset.
		print("ARQUIVO:", fl);
		time1 = getTime();
		

		for(f = 0; f < seriesCount; f++ ){ // descomente Essa linha pra analisar tudo
			
			//run("Bio-Formats Macro Extensions");
			time2 = getTime();
			Ext.setSeries(f);
			Ext.getSeriesName(seriesName);
			Ext.getImageCount(imageCount);
			Ext.getPixelType(pixelType);
			Ext.getEffectiveSizeC(effectiveSizeC);
			Ext.getDimensionOrder(dimOrder);
			print("Iniciando analise: ");
			print(f, imageCount, seriesName, pixelType, effectiveSizeC, dimOrder);
			//Ext.openImage("a", seriesName);
			print("Abrindo imagem... ");
	
		
			
			if (seriesName.contains("Merg")) {
				
				print("Bio-Formats Importer", "open='" + file + "' color_mode=Default view=Hyperstack stack_order=" + dimOrder + " use_virtual_stack series_"+d2s(f+1,0));

				run("Bio-Formats Importer", "open='" + file + "' color_mode=Default view=Hyperstack stack_order=" + dimOrder + " use_virtual_stack series_"+d2s(f+1,0));
				
				print("Analisando a imagem");
				
				name = getTitle();
				print(name);
				preproc(name);
				
				
				continue;
			} else {
				print("PULANDO IMAGEM...");
				//selectWindow(name);
				//run("Close");
				continue;
			} 
			

			
			print("Tempo gasto na imagem nº " + f + ": " + (getTime() - time2) + " msec");
			}
		print("Tempo gasto em todas as imagens: " + (getTime() - time1) + " msec");
		
		//run("Bio-Formats Macro Extensions");
		Ext.close();// Closes the active dataset.
		selectWindow("Log");
		//saveAs("Text", dir+outputdir+"/"+arquivos[arq]+"-Log.txt");
	}
	
} //final da macro


function preproc(window_name){
	
	print("PROCESSANDO " + window_name);
	
	selectWindow(window_name);
	run("Bin...", "x=2 y=2 bin=Average");
	name=getTitle();
	run("Split Channels");
	
	selectWindow("C1-"+name);
	rename("DAPI");
	selectWindow("C2-"+name);
	rename("CD31");
	
	if (name.contains("/")){
		
		new_name = name.replace("/",'_');
		
		print(new_name); 
		name = new_name;
		}
	
	
	// processando todas as celulas atraves do DAPI
	selectWindow("DAPI");
	
	run("Unsharp Mask...", "radius=1.5 mask=0.80");
	run("Gaussian Blur...", "sigma=1.0");
	run("Unsharp Mask...", "radius=1.5 mask=0.80");
	
	run("Duplicate...", " ");
	selectWindow("DAPI-1");
	rename("mask");
	run("Auto Threshold", "method=Default white");
	rename("DAPI_threshold");
	all_threshold = getTitle();
	
	selectWindow("DAPI");	
	raw_cells = getTitle();

	selectWindow(all_threshold);
	waitForUser("Draw a ROI containing only the placenta, then click OK"); 
	
	run("Create Mask");
	mask_placenta = getTitle(); // criando uma mascara para aplicar para o CD31 tambem 
	
	selectWindow(all_threshold);
	run("Clear Outside");
	all_threshold = getTitle();

	if (isOpen("ROI Manager")) {
	     selectWindow("ROI Manager");
	     run("Close");
	}
	
	selectWindow(all_threshold);
	run("Morphological Filters", "operation=Opening element=Disk radius=1");
	run("Area Opening", "pixel=2");
	
	run("Convert to Mask");
	all_threshold = getTitle();
	
	// processando apenas o CD31 
	selectWindow("CD31");
	run("Duplicate...", " ");
	rename("CD31_positive");

	// deixando o usuario escolher qual eh o melhor threshold para CD31 positivas 
	run("Threshold...");
	waitForUser("adjust threshold","Click OK when you are done");
	
	Dialog.create("select threshold");
	Dialog.addSlider("Threshold value", 0, 255, 19);
	Dialog.show();
	
	T = Dialog.getNumber();
	run("Threshold...");
	setThreshold(T, 255);
	setOption("BlackBackground", true);
	run("Convert to Mask");	
	CD31_threshold = getTitle();
	
	imageCalculator("Multiply create", mask_placenta, CD31_threshold);
	run("Convert to Mask");	
	CD31_positive = getTitle();
	
	// analisando todas as celulas em relacao a intensidade do CD31	
	selectWindow(all_threshold);
	run("Duplicate...", "title=DAPI_all-cells");
	selectWindow("DAPI_all-cells");
	run("Set Measurements...", "area mean shape area_fraction limit display redirect=CD31 decimal=4");
	run("Analyze Particles...", "  show=[Overlay Masks] display clear");
	print("saving table results");
	saveAs("Results",dir + "/" + outputdir +"/table_results/" + "all_cells_" + name + ".csv");
	
	//agora analisando a intensidade do CD31 apenas em celulas positivas (acima do threshold) 
	selectWindow(all_threshold);
	run("Morphological Filters", "operation=Dilation element=Disk radius=1");
	imageCalculator("AND create", CD31_positive , all_threshold + "-Dilation");
	//imageCalculator("AND create", CD31_positive , all_threshold);
	CD31_positive_inside_cells = getTitle();
	
	selectWindow(CD31_positive_inside_cells);
	//run("Morphological Filters", "operation=Opening element=Disk radius=1");
	run("Area Opening", "pixel=2"); //removendo cacarecos 
	run("Morphological Filters", "operation=Closing element=Disk radius=1");
	rename("final_mask");
	
	run("Marker-controlled Watershed", "input="+ raw_cells +" marker="+all_threshold+" mask=final_mask compactness=0 binary calculate use");
	run("Set Label Map", "colormap=[Golden angle] background=Black shuffle");
	wsd = getTitle();
	run("Intensity Measurements 2D/3D", "input=CD31 labels=" + wsd +" mean stddev max min median mode skewness kurtosis numberofvoxels volume neighborsmean neighborsstddev neighborsmax neighborsmin neighborsmedian neighborsmode neighborsskewness neighborskurtosis");
	
	print("NAME:  " + dir + "/" + outputdir +"/table_results/" );
	saveAs("Results",dir + "/" + outputdir +"/table_results/" + "CD31-positive_cells_" + name +"_T-" + T + ".csv");

	selectWindow(all_threshold);
	saveAs("Tiff", dir+"/"+outputdir +"/" + name + "_DAPI-all-cells.tif");
	result = getTitle();
	
	selectWindow(CD31_positive);
	saveAs("Tiff", dir+"/"+outputdir +"/" + name + "_CD31-positive.tif");
	result = getTitle();
	
	selectWindow(wsd);
	saveAs("Tiff",dir+"/"+outputdir +"/" +  name + "_CD31-watershed.tif");
	all_threshold = getTitle();
	
	janelas = getList("window.titles");
	
	
	for (i=0; i<janelas.length; i++){ 
		winame = janelas[i];
		print(winame);
		selectWindow(winame);
		run("Close");
     } 
	
	run("Close All");
	

	
}
run("Quit", "");