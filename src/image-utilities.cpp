#include <stdio.h>
#include <cmath>
#include <iostream>
#include <string>
#include<bits/stdc++.h>
#include <bitset>

#define SIZE 224
#define IMG 224
#define FILTERS 16 

short int inputVolume[2*SIZE][2*SIZE][512];
short int inputVolume1[2*SIZE][2*SIZE][512];
float filters[16][512][512][15];
int readArray[] = {1,2,1,2,1,2};
int storeArray[] = {1,2,1,2,1,2};
int row = 0;
int col = 0;
int counter = 0;
int count = 0;

typedef struct{
	short int d1;
	short int d2;
	short int d3;
	short int d4;
	short int d5;
	short int d6;
	short int d7;		
	short int d8;		
} packet;

long double stream[2048];
short int ID[10000000];
int streamC = 0;

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
		//printf("\n FILTER %d \n ", f);
		for(int s=0;s<depth; s++){
			//printf("\n DEPTH %d \n ", s);
			for(int k = 0; k<9;k++) {
				fscanf(file, "%f", &filters[k][s][f][l]);
				//printf(" %f ", filters[k][s][f][l]);
			} 
			//printf("\n  ############################### \n");
		}

		//printf(" \n --------------------------------------------- \n ");
        }
   }

}
extern "C"
{
        short int  getValue(int l, int s, int f, int i)
        {
                unsigned long num;
                short int y;
		short int one = 1;
		short int zero = 65534;
		
                if ( l <16 && s < 512 && f <512 && i< 15) {
                float n = filters[i][s][f][l];
                if(n<0)
                n = fabs(n);
                int k = 15;
                std::string a = decimalToBinary(n,k);
                std::bitset<16> x(a);
		num = x.to_ulong();
		y = (short int) num;
		y = (y>>1)<<1;
		
                if(filters[i][s][f][l] < 0)
                        y = (y | 0x0001);
                        
		return y;
                }
                else
                        return 0;
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
	


	for(int filters = 0; filters < 2; filters++) {
	for(int depth = 0; depth < 1; depth++) {
	for(int i = 0; i<FILTERS; i++){
        for(int j=0; j<9; j++){
                for(int k=0; k<3; k++)
                        	ID[counter++] = getValue(0,k,filters*FILTERS + i,j) ;
                        	ID[counter++] = 0; 
                for(int k=0; k<4; k = k + 1)
                        ID[counter++] = (k+1);
        	}
    	}
	

	for(int i=0 ;i<IMG; i+=2){
                for(int j=0;j<IMG; j++){
                        for(int k=0;k<4; k++)
                               	ID[counter++] = ((inputVolume[i][j][k]))<< 6;
                        for(int k=0;k<4; k++)
                                ID[counter++] = ((inputVolume[i+1][j][k])) << 6 ;
                }
        }
	}
	}



	/*for(int depth = 0 ; depth < 8; depth++) {     
        for(int i = 0; i<FILTERS; i++){
                for(int j=0; j<9; j++){
                        for(int k=0; k<4; k++)
                        ID[counter++] = getValue(1, depth*4 + k, i,j);
                        for(int k=0; k<4; k = k + 1)
                        ID[counter++] = (k+1);
                        }
        }

        for(int i=0 ;i<IMG; i+=2){
                for(int j=0;j<IMG; j++){
                        for(int k=0;k<4; k++)
                                ID[counter++] = ((inputVolume[i][j][k]))<< 6;
                        for(int k=0;k<4; k++)
                                ID[counter++] = ((inputVolume[i+1][j][k])) << 6 ;
                }
        }
        }*/

	
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
			if (ri < SIZE && cj < SIZE) {
                        return inputVolume1[ri][cj][ch];
			}
                	else
                        return 0;
                }

			
	}
}

extern "C"
{       
        short int readPixel1(int ri, int cj, int ch, int layer)
        {
                
                if(readArray[layer] == 1) { 
                        if (ri < SIZE && cj < SIZE)
                                return inputVolume[ri][cj][ch];
                        else    
                                return 0;
                }
                else
                {       
                        if (ri < SIZE && cj < SIZE) {
                        return inputVolume1[ri][cj][ch];
                        }
                        else
                        return 0;
                }

         
        }
}


extern "C"
{
	void storePixel(short int data1, short int data2, short int data3,short int data4, short int data5, short int data6,short int data7,short int data8, int slice, int layer, int img, int pool)
	{
		
		std::bitset<16> val1(data1);
                std::string number1 = val1.to_string();
                double x1 = binaryToDecimal(number1,16);
		
		std::bitset<16> val2(data2);
                std::string number2 = val2.to_string();
                double x2 = binaryToDecimal(number2,16);

		std::bitset<16> val3(data3);
                std::string number3 = val3.to_string();
                double x3 = binaryToDecimal(number3,16);

		std::bitset<16> val4(data4);
                std::string number4 = val4.to_string();
                double x4 = binaryToDecimal(number4,16);

		std::bitset<16> val5(data5);
                std::string number5 = val5.to_string();
                double x5 = binaryToDecimal(number5,16);

		std::bitset<16> val6(data6);
                std::string number6 = val6.to_string();
                double x6 = binaryToDecimal(number6,16);
		
		std::bitset<16> val7(data7);
                std::string number7 = val7.to_string();
                double x7 = binaryToDecimal(number7,16);
		
		std::bitset<16> val8(data8);
                std::string number8 = val8.to_string();
                double x8 = binaryToDecimal(number8,16);

		count++;
		if(pool == 0) {
		if(row < img-2 && col < img-2) {
			if(storeArray[layer] == 1)
			{
				inputVolume[(row+1)][(col+1)][slice + 0] = (float)x1;
				inputVolume[(row+2)][(col+1)][slice + 0] = (float)x2;

				inputVolume[(row+1)][(col+1)][slice + 1] = (float)x3;
                		inputVolume[(row+2)][(col+1)][slice + 1] = (float)x4;

				inputVolume[(row+1)][(col+1)][slice + 2] = (float)x5;
                                inputVolume[(row+2)][(col+1)][slice + 2] = (float)x6;

				inputVolume[(row+1)][(col+1)][slice + 3] = (float)x7;
                                inputVolume[(row+2)][(col+1)][slice + 3] = (float)x8;			
			
			}
			else
			{
				inputVolume1[(row+1)][(col+1)][slice + 0] = (float)x1;
                                inputVolume1[(row+2)][(col+1)][slice + 0] = (float)x2;

                                inputVolume1[(row+1)][(col+1)][slice + 1] = (float)x3;
                                inputVolume1[(row+2)][(col+1)][slice + 1] = (float)x4;

                                inputVolume1[(row+1)][(col+1)][slice + 2] = (float)x5;
                                inputVolume1[(row+2)][(col+1)][slice + 2] = (float)x6;

                                inputVolume1[(row+1)][(col+1)][slice + 3] = (float)x7;
                                inputVolume1[(row+2)][(col+1)][slice + 3] = (float)x8;

		
			}
		}
		}
		else{
			if(row < (img/2 - 1) && col < (img/2-1)) {
				if(storeArray[layer] == 1)
				{
				inputVolume[(row+1)][(col+1)][slice + 0] = (float)x1;
				inputVolume[(row+1)][(col+1)][slice + 1] = (float)x3;
				inputVolume[(row+1)][(col+1)][slice + 2] = (float)x5;
				inputVolume[(row+1)][(col+1)][slice + 3] = (float)x7;
				}
				else
				{
					
				inputVolume1[(row+1)][(col+1)][slice + 0] = (float)x1;
                                inputVolume1[(row+1)][(col+1)][slice + 1] = (float)x3;
                                inputVolume1[(row+1)][(col+1)][slice + 2] = (float)x5;
                                inputVolume1[(row+1)][(col+1)][slice + 3] = (float)x7;
				}
			}
		}

		if(col == img-3) {
			if(row + 2 >= img-2) {
				count = 0;
				row = 0;
			}
			else
				row += 2;
			col = 0;
		}
		else
			col += 1;	
		 
		
	}
	
}

extern "C"
{
void printVolume(){

	for(int k=0;k<32;k++) 
		for(int i=0; i<IMG; i++) {
			inputVolume1[0][i][k] = 0;
			inputVolume1[IMG-1][i][k] = 0;
			inputVolume1[i][0][k] = 0;
			inputVolume1[i][IMG-1][k] = 0;
		}
	
	
	for(int depth = 0 ; depth < 8; depth++) {
        for(int i = 0; i<FILTERS; i++){
                for(int j=0; j<9; j++){
                        for(int k=0; k<4; k++)
                        ID[counter++] = getValue(1, depth*4 + k, i,j);
                        for(int k=0; k<4; k = k + 1)
                        ID[counter++] = (k+1);
                        }
        }

        for(int i=0 ;i<IMG; i+=2){
                for(int j=0;j<IMG; j++){
                        for(int k=0;k<4; k++)
                                ID[counter++] = ((inputVolume1[i][j][k]))<< 6;
                        for(int k=0;k<4; k++)
                                ID[counter++] = ((inputVolume1[i+1][j][k])) << 6 ;
                }
        }
        }
		
			
}
}

extern "C"
{
	short int streamData1(int index){
			return ID[streamC + index];
			
	}
	
}
extern "C"
{
        void inc(){
                        streamC+=8;

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

int main()
{	
	initialize_imageCPP();
	   for(int i=1152; i<1200; i+=4)
                std::cout<<ID[i] << "  ";
}

