#include <stdlib.h>
#include <stdio.h>
#include <cmath>
#include <iostream>
#include <string>
#include<bits/stdc++.h>
#include <bitset>
using namespace std;

float filters[16][512][512][15];

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

double binaryToDecimal(std::string binary, int len)
{
    size_t point = binary.find('.');
    double intDecimal = 0, fracDecimal = 0, twos = 1;
    for (int i = 0; i>=0; --i)
    {
        intDecimal += (binary[i] - '0') * twos;
        twos *= 2;
    }
    twos = 2;
    for (int i = 1; i < 16; ++i)
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

short int  getValue(int l, int s, int f, int i)
{
		printf(" %f \n\n ", filters[i][s][f][l]);
		
                if ( l <16 && s < 512 && f <512 && i< 15) {
                float n = filters[i][s][f][l];
                if(n<0)
                n = fabs(n);
                int k = 15;
                std::string a = decimalToBinary(n,k);
                std::bitset<16> x(a);
		std::cout<<x[0]<<"  "<<x.to_string()<<"\n\n";
                unsigned long num = x.to_ulong();
                short int y = (short int) num;
		//x[0]=0;
		std::cout<<binaryToDecimal(x.to_string(),15);
                return y;

                }
                else
                        return 0;
}

void makeStream()
{
	
}
int main()
{
	load_weights();
	getValue(0,0,0,8);
	
	long double *stream = (long double *) malloc(sizeof(long double) * 100);
	short int *id = (short int *)stream;
	return 0;
}
