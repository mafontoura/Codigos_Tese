macro "Analisar imagens de citoqueratina" {
	
	
	arquivos = newArray(0);
	dir = getDirectory("Escolha uma Pasta com as imagens .lif");
	//dir = "/ibira/lnbio/20210021/lifs_para_analise/";
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
	
		
			
			if (seriesName.contains("Merge")) {
				
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
	rename("citoq");
	
	// processando todas as celulas atraves do DAPI
	selectWindow("DAPI");
	print("filtros");
	run("Bandpass Filter...", "filter_large=40 filter_small=1 suppress=Horizontal tolerance=10 autoscale saturate");
	run("Bandpass Filter...", "filter_large=40 filter_small=1 suppress=Vertical tolerance=10 autoscale saturate");
	print("remove background");
	run("Remove Background", "radius=20");
	run("Invert");
	run("Auto Threshold", "method=Triangle white"); //Default
	run("Morphological Filters", "operation=Closing element=Disk radius=20");
	run("Fill Holes");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	setOption("BlackBackground", true); //new
	all_cells = getTitle();
	
	// processando apenas o labirinto marcado com citoqueratina
	selectWindow("citoq");
	run("Gaussian Blur...", "sigma=5");
	gauss=getTitle();
	run("Duplicate...", " ");
	rename("Threshold");
	
	//deixando o usuario escolher o melhor threshold versao nova 
	selectWindow(gauss);
	run("Auto Threshold", "method=[Try all] white");
	waitForUser("Choose best threshold img","Click OK when you are done :)");
	
	t_array = newArray("Default","Huang","Huang2","Intermodes","IsoData","Li", "MaxEntropy", "Mean", "MinError(I)", "Minimum", "Moments", "Otsu", "Percentile", "RenyiEntropy", "Shanbhag", "Triangle", "Yen");
	Dialog.create("Select your best threshold");
	Dialog.addMessage("Count on the board from left to right, top to botton and select the number of the image that makes the best threshold");
	Dialog.addNumber("Img number that has the best threshold", 16);
	Dialog.show();
	
	T = Dialog.getNumber();
	method = t_array[T-1];
	print("The selected threshold method name was: ", method); 
	
	selectWindow(gauss);
	run("Auto Threshold", "method="+method+" white");
	
	/// para selecionar apenas o labirinto e evitar coisas fora dele 
	waitForUser("Draw a ROI containing only the placenta, then click OK"); 

	if (isOpen("ROI Manager")) {
	     selectWindow("ROI Manager");
	     run("Close");
	}
	run("Clear Outside");
	
	run("Convert to Mask");
	

	///
	run("Fill Holes");
	run("Morphological Filters", "operation=Closing element=Disk radius=20");
	run("Fill Holes");
	lab = getTitle();
	
	// todas as celulas - labirinto para achar a proporcao lab/all_cells
	imageCalculator("Subtract create", all_cells,lab);
	result = getTitle();

	
	selectWindow(result);
	saveAs("Tiff", dir+"/"+outputdir +"/" + name + "_subtract-result.tif");
	result = getTitle();
	
	selectWindow(all_cells);
	saveAs("Tiff",dir+"/"+outputdir +"/" +  name + "_all-cells.tif");
	all_cells = getTitle();
	
	selectWindow(lab);
	saveAs("Tiff", dir+"/"+outputdir +"/" + name + "_T-"+method+"_labirinto.tif");	
	lab= getTitle();
	
	// medindo as areas e as fracoes das areas
	run("Set Measurements...", "area centroid perimeter shape feret's area_fraction limit display redirect=None decimal=4");
	
	selectWindow(all_cells);
	run("Convert to Mask");
	run("Measure");
	
	selectWindow(lab);
	run("Convert to Mask");
	run("Measure");
	
	selectWindow(result);
	run("Convert to Mask");
	run("Measure");
	saveAs("Results", dir + "/" + outputdir +"/table_results/" + "Table_" + name + ".csv");
	
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