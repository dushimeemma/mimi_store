import { BadRequestException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary, UploadApiErrorResponse, UploadApiResponse } from 'cloudinary';

export interface ProductImage {
  imageUrl: string;
  imagePublicId: string;
}

@Injectable()
export class MediaService {
  private readonly folder: string;
  private readonly enabled: boolean;

  constructor(private readonly config: ConfigService) {
    const cloudName=config.get<string>('CLOUDINARY_CLOUD_NAME');
    const apiKey=config.get<string>('CLOUDINARY_API_KEY');
    const apiSecret=config.get<string>('CLOUDINARY_API_SECRET');
    this.folder=(config.get<string>('CLOUDINARY_PRODUCT_FOLDER')??'mimi-store/products').replace(/^\/+|\/+$/g,'');
    this.enabled=Boolean(cloudName&&apiKey&&apiSecret);
    if(this.enabled)cloudinary.config({cloud_name:cloudName,api_key:apiKey,api_secret:apiSecret,secure:true});
  }

  async uploadProductImage(file: Express.Multer.File): Promise<ProductImage> {
    if(!this.enabled)throw new ServiceUnavailableException('Cloudinary image uploads are not configured');
    if(!file?.buffer?.length)throw new BadRequestException('Select an image to upload');
    if(!['image/jpeg','image/png','image/webp'].includes(file.mimetype))throw new BadRequestException('Only JPG, PNG and WebP images are supported');
    if(file.size>8*1024*1024)throw new BadRequestException('Product image must be 8 MB or smaller');
    const result=await new Promise<UploadApiResponse>((resolve,reject)=>{
      const stream=cloudinary.uploader.upload_stream({folder:this.folder,resource_type:'image',overwrite:false,use_filename:true,unique_filename:true},(error:UploadApiErrorResponse|undefined,response:UploadApiResponse|undefined)=>error||!response?reject(error??new Error('Cloudinary upload failed')):resolve(response));
      stream.end(file.buffer);
    });
    return {imageUrl:result.secure_url,imagePublicId:result.public_id};
  }

  async deleteProductImage(publicId:string|undefined|null):Promise<void>{
    if(!publicId||!this.enabled)return;
    if(!publicId.startsWith(`${this.folder}/`))throw new BadRequestException('Invalid Mimi Store product image identifier');
    const result=await cloudinary.uploader.destroy(publicId,{resource_type:'image',invalidate:true});
    if(!['ok','not found'].includes(result.result))throw new Error(`Cloudinary delete failed: ${result.result}`);
  }
}
