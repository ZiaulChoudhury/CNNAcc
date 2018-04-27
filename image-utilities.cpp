#include <stdio.h>
#include <cmath>
#include <iostream>
#include <string>
#include<bits/stdc++.h>
#include <bitset>

#define SIZE 224
short int inputVolume[2*SIZE][2*SIZE][512];
short int inputVolume1[2*SIZE][2*SIZE][512];
float filters[16][512][512][15];
int readArray[] = {1,2,1,2,1,2};
int storeArray[] = {1,2,1,2,1,2};

double binaryToDecimal(std::string binary, int len)
{
    size_t point = binary.find('.');
    double intDecimal = 0, fracDecimal = 0, twos = 1;
    for (int i = 9; i>=0; --i)
    {
        intDecimal += (binary[i] - '0') * twos;
        twos *= 2;
    }
    twos = 2;
    for (int i = 10; i < 16; ++i)
    {
        fracDecimal += (binary[i] - '0') / twos;
        twos *= 2.0;
    }
    return intDecimal + fracDecimal;
}


std::string decimalToBinary(double num, int k_prec)
{
    std::string binary = "";
    int Integral = num; 
    double fractional = num - Integral;
    while (Integral)
    {
        int rem = Integral % 2;

        binary.push_back(rem +'0');
        
        Integral /= 2;
    }
    reverse(binary.begin(),binary.end());
    while (k_prec--)
    {
        fractional *= 2;
        int fract_bit = fractional;

        if (fract_bit == 1)
        {   
            fractional -= fract_bit;
            binary.push_back(1 + '0');
        }
        else
            binary.push_back(0 + '0');
    }
    return binary;
}
// the format for storing the weights is first [row][col][depth][filters][layers] // 
void load_weights()
{
	
    FILE* file = fopen ("weights.txt", "r");
    int layer, depth, fils;
    for(int l = 0; l <13 ; l++) { 
    fscanf(file,"%d %d %d", &layer, &depth, &fils);   
    	for(int f = 0; f< fils; f++) {
		for(int s=0;s<depth; s++){
			for(int k = 0; k<9;k++) {
				fscanf(file, "%f", &filters[k][s][f][l]);
				if(filters[k][s][f][l] == 0) {
					std::cout << " ET DETECTED ";
					exit(0);
				}
			} 
		}
        }
   }

}

void initialize_imageCPP()
{
	
    load_weights();
    FILE* file = fopen ("input/drive.txt", "r");
    int i = 0, j=0,k=0;
    int count = 0;

  	fscanf (file, "%d %d %d", &i, &j, &k);    
  	while (!feof (file))
    	{ 	
	         inputVolume[count/SIZE][count%SIZE][0] = i;
	         inputVolume[count/SIZE][count%SIZE][1] = j;
	         inputVolume[count/SIZE][count%SIZE][2] = k;
		 count ++;
      		 fscanf (file, "%d %d %d", &i, &j, &k);          
    	}
  	fclose (file);    
}
extern "C" {
	        void  initialize_image()
		{
			initialize_imageCPP();
		}
}

extern "C" 
{
	short int readPixel(int ri, int cj, int ch, int layer)
	{
		if(readArray[layer] == 1) {
			if (ri < SIZE && cj < SIZE)
				return inputVolume[ri][cj][ch];
			else
				return 0;
		}
		else 
		{
			if (ri < SIZE && cj < SIZE)
                        return inputVolume1[ri][cj][ch];
                	else
                        return 0;
                }

			
	}
}

extern "C"
{
	void storePixel(short int data, int ri, int cj, int ch, int layer, int img, int pad)
	{
		std::bitset<16> val(data);
                std::string number = val.to_string();
                double x = binaryToDecimal(number,16);
		if(pad == 1)
		{
			for(int i=0;i<img;i++)
			{
				if(storeArray[layer] == 1) {
					inputVolume[0][i][ch] = 0;
					inputVolume[img-1][i][ch] = 0;
				}
				else{
					inputVolume1[0][i][ch] = 0;
					inputVolume1[img-1][i][ch] = 0;
				}
			}
		}

		if(storeArray[layer] == 1)
		{ 
                        if (ri < SIZE && cj < SIZE) {
                                inputVolume[ri][cj][ch] = (float)x;
				if(layer == 4)
					std::cout <<inputVolume[ri][cj][ch] << "\n";
				//std::cout<< "r " << ri << " c " << cj << " d " << ch << " --> "  << inputVolume[ri][cj][ch] << " \n ";
			}
                }
                else
		{
                        if (ri < SIZE && cj < SIZE) {
                        	inputVolume1[ri][cj][ch] = (float)x;
				if(layer == 4)
					std::cout << inputVolume1[ri][cj][ch] << "\n";
				//std::cout<< "r " << ri << " c " << cj << " d " << ch << " --> "  << inputVolume1[ri][cj][ch] << " \n ";
			}
				
                }

	}
	
}
extern "C"
{
        short int  getValue(int l, int s, int f, int i)
	{
		if ( l <16 && s < 512 && f <512 && i< 15) {
        	float n = filters[i][s][f][l];
		if(n<0)
		n = fabs(n);
        	int k = 15;
        	std::string a = decimalToBinary(n,k);
       		std::bitset<16> x(a);
        	unsigned long num = x.to_ulong();
        	short int y = (short int) num;
        	return y;
		}
		else
			return 0;
        }
	
}
extern "C"
{
	int checkSign(int l, int s, int f, int i){

		if ( l <16 && s < 512 && f <512 && i< 15) {
		if(filters[i][s][f][l] < 0)
			return 1;
		else
			return 0;
		}
		else
			return 0;
	}
}

/*int main()
{	
	initialize_imageCPP();
	load_weights();
	return 0;
}*/
