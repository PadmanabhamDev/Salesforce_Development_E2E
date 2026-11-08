import { LightningElement } from 'lwc';
import getImage from '@salesforce/apex/CloudVisionController.getImageInfo';
export default class CloudVisionController extends LightningElement {

    handleClick() {
        getImage()
            .then(result => {
                console.log(result);
            })
            .catch(error => {
                console.log(error);
            })
    }
}