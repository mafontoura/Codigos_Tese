macro "Analisar imagens de H2A" {
	
	
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
	rename("H2A");
	
	if (name.contains("/")){
		
		new_name = name.replace("/",'_');
		
		print(new_name); 
		name = new_name;
		}
	
	
	// processando todas as celulas atraves do DAPI
	selectWindow("DAPI");
	
	run("Unsharp Mask...", "radius=1 mask=0.60");
	run("Gaussian Blur...", "sigma=1.5");
	run("Unsharp Mask...", "radius=1 mask=0.60");
	
	run("Duplicate...", " ");
	selectWindow("DAPI-1");
	rename("mask");
	run("Auto Threshold", "method=Li white");
	
	selectWindow("DAPI");
	run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=mask fast_(less_accurate)");
	raw_cells = getTitle();
	run("Duplicate...", " ");
	rename("DAPI_threshold");
	run("Auto Local Threshold", "method=Bernsen radius=15 parameter_1=0 parameter_2=0 white");
	run("Area Opening", "pixel=2");
	all_threshold = getTitle();
	
	waitForUser("Draw a ROI containing only the placenta, then click OK"); 
	
	run("Create Mask");
	mask_placenta = getTitle(); // criando uma mascara para aplicar para o H2A tambem 
	
	selectWindow(all_threshold);
	run("Clear Outside");
	all_threshold = getTitle();

	if (isOpen("ROI Manager")) {
	     selectWindow("ROI Manager");
	     run("Close");
	}
	
	selectWindow(all_threshold);
	run("Convert to Mask");
	all_threshold = getTitle();
	
	// processando apenas o H2A 
	selectWindow("H2A");
	run("Duplicate...", " ");
	rename("H2A_positive");

	// deixando o usuario escolher qual eh o melhor threshold para H2A positivas 
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
	H2A_threshold = getTitle();
	
	imageCalculator("Multiply create", mask_placenta, H2A_threshold);
	run("Convert to Mask");	
	H2A_positive = getTitle();
	
	// analisando todas as celulas em relacao a intensidade do H2A	
	selectWindow(all_threshold);
	run("Duplicate...", "title=DAPI_all-cells");
	selectWindow("DAPI_all-cells");
	run("Set Measurements...", "area mean shape area_fraction limit display redirect=H2A decimal=4");
	run("Analyze Particles...", "  show=[Overlay Masks] display clear");
	print("saving table results");
	saveAs("Results",dir + "/" + outputdir +"/table_results/" + "all_cells_" + name + ".csv");
	
	//agora analisando a intensidade do H2A apenas em celulas positivas (acima do threshold) 
	selectWindow(all_threshold);
	//run("Morphological Filters", "operation=Dilation element=Disk radius=1");
	//imageCalculator("AND create", H2A_positive , all_threshold + "-Dilation");
	imageCalculator("AND create", H2A_positive , all_threshold);
	H2A_positive_inside_cells = getTitle();
	
	selectWindow(H2A_positive_inside_cells);
	run("Area Opening", "pixel=2"); //removendo cacarecos 
	run("Morphological Filters", "operation=Closing element=Disk radius=1");
	rename("final_mask");
	
	run("Marker-controlled Watershed", "input="+ raw_cells +" marker="+all_threshold+" mask=final_mask compactness=0 binary calculate use");
	run("Set Label Map", "colormap=[Golden angle] background=Black shuffle");
	wsd = getTitle();
	run("Intensity Measurements 2D/3D", "input=H2A labels=" + wsd +" mean stddev max min median mode skewness kurtosis numberofvoxels volume neighborsmean neighborsstddev neighborsmax neighborsmin neighborsmedian neighborsmode neighborsskewness neighborskurtosis");
	
	print("NAME:  " + dir + "/" + outputdir +"/table_results/" );
	saveAs("Results",dir + "/" + outputdir +"/table_results/" + "H2A-positive_cells_" + name +"_T-" + T + ".csv");

	selectWindow(all_threshold);
	saveAs("Tiff", dir+"/"+outputdir +"/" + name + "_DAPI-all-cells.tif");
	result = getTitle();
	
	selectWindow(H2A_positive);
	saveAs("Tiff", dir+"/"+outputdir +"/" + name + "_H2A-positive.tif");
	result = getTitle();
	
	selectWindow(wsd);
	saveAs("Tiff",dir+"/"+outputdir +"/" +  name + "_H2A-watershed.tif");
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