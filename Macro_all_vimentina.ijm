macro "Analisar imagens de VIMENTINA" {
	
	
	arquivos = newArray(0);
	dir = getDirectory("Escolha uma Pasta com as imagens .lif");
	//dir = "/ibira/lnbio/20210021/lifs_para_analise/";
	list = getFileList(dir);
	for(i = 0; i < list.length; i++) {
		
		if(list[i].contains("Ctrl647")) {
			
			print("Essa eh uma imagem controle"); 
			continue;
			}
	
	else{	
		
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
	rename("vimentina");
	run("Brightness/Contrast...");
	run("Enhance Contrast", "saturated=0.35");
	call("ij.ImagePlus.setDefault16bitRange", 8);
	setMinAndMax(0, 25);
	
	
	if (name.contains("/")){
		
		new_name = name.replace("/",'_');
		
		print(new_name); 
		name = new_name;
		}
	
	
	// processando todas as celulas atraves do DAPI
	selectWindow("DAPI");
	
	run("Unsharp Mask...", "radius=1 mask=0.60");
	run("Gaussian Blur...", "sigma=1.5");
	//run("Unsharp Mask...", "radius=1 mask=0.60");
	
	rename("DAPI_threshold");
	//run("Auto Local Threshold", "method=Bernsen radius=15 parameter_1=0 parameter_2=0 white");
	run("Auto Threshold", "method=Triangle white"); //Default
	run("Morphological Filters", "operation=Closing element=Disk radius=20");
	run("Fill Holes");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	rename("DAPI_threshold");
	DAPI_threshold = getTitle();
	
	
	selectWindow(DAPI_threshold);
	waitForUser("Draw a ROI containing only the placenta, then click OK"); 
	
	run("Create Mask");
	mask_placenta = getTitle(); // criando uma mascara para aplicar para a vimentina tambem 
	
	selectWindow(DAPI_threshold);
	run("Clear Outside");
	DAPI_threshold = getTitle();

	if (isOpen("ROI Manager")) {
	     selectWindow("ROI Manager");
	     run("Close");
	}
	
	selectWindow(DAPI_threshold);	
	run("Convert to Mask");
	
	
	// a partir de agora processando o canal de vimentina 
	selectWindow("vimentina");	
	run("Duplicate...", " ");
	rename("vimentina-threshold");
	//run("Gaussian Blur...", "sigma=2");
	run("Non-local Means Denoising", "sigma=4 smoothing_factor=0.5");
	run("Unsharp Mask...", "radius=2 mask=0.80");
	run("Gaussian Blur...", "sigma=1");
	
	// deixando o usuario escolher qual eh o melhor threshold
	selectWindow("vimentina-threshold");
	run("Auto Threshold", "method=[Try all] white");
	waitForUser("Choose threshold","Click OK when you are done :)");
	
	
	t_array = newArray("Default","Huang","Huang2","Intermodes","IsoData","Li", "MaxEntropy", "Mean", "MinError(I)", "Minimum", "Moments", "Otsu", "Percentile", "RenyiEntropy", "Shanbhag", "Triangle", "Yen");
	Dialog.create("Select your best threshold");
	Dialog.addMessage("Count on the board from left to right, top to botton and select the number of the image that makes the best threshold");
	Dialog.addMessage("This threshold img will be eroded later, small dots will vanish");
	Dialog.addNumber("Img number that has the best threshold", 9);
	Dialog.show();
	
	T = Dialog.getNumber();
	method = t_array[T-1];
	print("The selected threshold method name was: ", method); 
	
	//threshold
	selectWindow("vimentina-threshold");
	run("Auto Threshold", "method="+method+" white");
	//run("Morphological Filters", "operation=Closing element=Disk radius=1.5");
	//run("Area Opening", "pixel=110");
	run("Morphological Filters", "operation=Closing element=Disk radius=1");
	run("Area Opening", "pixel=55");
	
	vimentina_mark = getTitle();
	imageCalculator("Multiply create", mask_placenta, vimentina_mark); //mantendo o mesmo marcador com a vimentina 
	//run("Convert to Mask");
	rename("vimentina_threshold");
	
	//calculando a espessura local dos vasos marcados com vimentina 
	run("Duplicate...", " ");
	run("Local Thickness (masked, calibrated, silent)");
	rename("local_thickness"); 
	
	
	//avaliando a area total das celulas 
	selectWindow(DAPI_threshold);
	run("Set Measurements...", "area mean fit area_fraction limit display redirect=DAPI_threshold decimal=4");
	run("Measure");	
	print("saving table results");
	saveAs("Results",dir + "/" + outputdir +"/table_results/" + "all-cells_" + name +"_T-" + method + ".csv");
	run("Close");
	
	// avaliando a espessura media dos vasos marcados com vimentina
	selectWindow("vimentina_threshold");
	run("Set Measurements...", "area mean modal min fit area_fraction limit display redirect=local_thickness decimal=4");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	setOption("BlackBackground", true);
	run("Measure");	
	print("saving table avg thickness results");
	saveAs("Results",dir + "/" + outputdir +"/table_results/" + "vim-thickness_" + name +"_T-" + method + ".csv");
	run("Close");
	
	// avaliando o comprimento total dos vasos 
	selectWindow("vimentina_threshold");
	run("Duplicate...", " ");
	
	rename("skeleton"); 
	run("Skeletonize");
	run("Convert to Mask");
	setOption("BlackBackground", true);
	skeleton = getTitle();
	run("Set Measurements...", "area mean fit area_fraction limit display redirect=skeleton decimal=4");
	selectWindow(skeleton);
	run("Measure");	
	print("saving table results");
	saveAs("Results",dir + "/" + outputdir +"/table_results/" + "vim-skeleton_" + name +"_T-" + method + ".csv");
	run("Close");
	
	//salvando  imagens
	selectWindow(DAPI_threshold);
	saveAs("Tiff", dir+"/"+outputdir +"/" + name + "_all-cells_T-"+method+".tif"); 
	
	selectWindow("local_thickness");
	saveAs("Tiff", dir+"/"+outputdir +"/" + name + "_vim-thickness_T-"+method+".tif");
	
	selectWindow(skeleton);
	saveAs("Tiff", dir+"/"+outputdir +"/" + name + "_vim-skeleton_T-"+method+".tif");
	
	
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