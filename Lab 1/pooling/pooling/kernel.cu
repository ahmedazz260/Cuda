#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <time.h>
#include "lodepng.h"
#define MAX_THREAD 1024

__global__ void max_pooling(unsigned char* original_img, unsigned char* new_img, unsigned int width, unsigned int num_thread, unsigned int size) {
	unsigned int position;
	unsigned char max;
	for (int i = threadIdx.x; i < size/4; i = i + num_thread) {
		position = i + (4 * (i / 4)) + (width * 4 * (i / (width * 2)));
		max = original_img[position];
		if (original_img[position + 4] > max)
			max = original_img[position + 4];
		if (original_img[position + width] > max)
			max = original_img[position + width];
		if (original_img[position + width + 4] > max)
			max = original_img[position + width + 1];

		new_img[i] = max;
	}
}

int main(int argc, char* argv[]) {
	if (argc != 4) {
		printf("Invalid number of arguments\n");
		return -1;
	}
	clock_t start = clock();

	unsigned char* original_img, * new_img;
	unsigned char* original_cudaImg, * new_cudaImg;

	unsigned int num_thread = atoi(argv[3]);
	unsigned width, height;
	unsigned int imagesize;
	unsigned error;
	error = lodepng_decode32_file(&original_img, &width, &height,
		argv[1]);
	if (error) {
		printf("%d: %s\n", error, lodepng_error_text(error));
		return -1;
	}
	printf("%d %d\n",width, height);
	imagesize = width * height * 4 * sizeof(unsigned char);
	new_img = (unsigned char*)malloc(imagesize/4);

	cudaMalloc((void**)&original_cudaImg, imagesize);
	cudaMalloc((void**)&new_cudaImg, imagesize/4);
	cudaMemcpy(original_cudaImg, original_img, imagesize, cudaMemcpyHostToDevice);

	max_pooling<< <1, num_thread >> > (original_cudaImg, new_cudaImg, width, num_thread, imagesize);

	cudaDeviceSynchronize();
	cudaMemcpy(new_img, new_cudaImg, imagesize/4, cudaMemcpyDeviceToHost);

	error = lodepng_encode32_file(argv[2], new_img, width/2, height/2);
	if (error) {
		printf("%d: %s\n", error, lodepng_error_text(error));
		return -1;
	}
	printf("%ul msec", clock() - start);

	free(original_img);
	free(new_img);
	cudaFree(original_cudaImg);
	cudaFree(new_cudaImg);

	return 0;
}