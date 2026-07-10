from __future__ import print_function, division

import pandas as pd
import torch
import torch.nn as nn
import torch.optim as optim
from torch.optim import lr_scheduler
import numpy as np
import torchvision
from torchvision import datasets, models, transforms
import matplotlib
import matplotlib.pyplot as plt
import time
import os
import copy
import PIL
from PIL import Image
import torch
import torch.nn as nn
import torch.optim as optim
from torch.optim import lr_scheduler
from os import listdir
from os.path import isfile, join
import glob
from torch.autograd import Variable
import torch.nn.functional as F
import platform, psutil
from datetime import date
import datetime, time
import sklearn.metrics as metrics
from sklearn.metrics import confusion_matrix
from sklearn.metrics import classification_report
import seaborn as sns
plt.ion()

print(os.getcwd())
print('Session START :', time.strftime('%Y-%m-%d %Z %H:%M:%S', time.localtime(time.time())))
print('===============================================================')
def printOsInfo():

    print('GPU                  :\t', torch.cuda.get_device_name(0)) 

    print('OS                   :\t', platform.system())
    


if __name__ == '__main__':

    printOsInfo()

def printSystemInfor():

    print('Process information  :\t', platform.processor())
    
    print('Process Architecture :\t', platform.machine())
    
    print('RAM Size             :\t',str(round(psutil.virtual_memory().total / (1024.0 **3)))+"(GB)")
    
    print('===============================================================')
      

if __name__ == '__main__':

    printSystemInfor()  


print('Pytorch')
print('torch ' + torch.__version__)
print('numpy ' + np.__version__)
print('torchvision ' + torch.__version__)
print('matplotlib ' + matplotlib.__version__)
print('pillow ' + PIL.__version__)
print('pandas ' + pd.__version__)
print('seaborn ' + sns.__version__)   
print('psutil ' + psutil.__version__) 
print('===============================================================')
    

data_transforms = {
        'test': transforms.Compose([
        transforms.RandomResizedCrop(224),
        transforms.RandomHorizontalFlip(),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])])}

data_dir = 'image'

path = {x: os.path.join(os.path.dirname(os.path.abspath("./image/")),data_dir,x)
                for x in ['test']}


image_datasets = {x: datasets.ImageFolder(path[x],
                                          data_transforms[x])
                  for x in ['test']}

dataloaders = { 'test' : torch.utils.data.DataLoader(image_datasets['test'], batch_size=84,
                                             shuffle=True, num_workers=4)  }

dataset_sizes = {x: len(image_datasets[x]) for x in ['test']}

class_names = image_datasets['test'].classes

filenames = glob.glob('./image/test/*/*.JPG')

def load_checkpoint(filepath, map_location='cpu'):
    checkpoint = torch.load(filepath)
    model = checkpoint['model_ft']
    model.load_state_dict(checkpoint['state_dict'], strict=False)
    model.class_to_idx = checkpoint['class_to_idx']
    optimizer_ft = checkpoint['optimizer_ft']
    epochs = checkpoint['epochs']

    for param in model.parameters():
        param.requires_grad = False

    return model, checkpoint['class_to_idx']

ckpt = torch.load("./weights/new_opencv_ckpt_b84_e200.pth")
ckpt.keys()

model, class_to_idx = load_checkpoint("./weights/new_opencv_ckpt_b84_e200.pth")

image_size = 224
norm_mean = [0.485, 0.456, 0.406]
norm_std = [0.229, 0.224, 0.225]

map_location = 'cpu'

strict = False

device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
        

def predict2(image_path, model, topk=5):
    img = Image.open(image_path)
    img = process_image(img)

    img = np.expand_dims(img, 0)

    img = torch.from_numpy(img)

    model.eval()
    inputs = Variable(img).to(device)
    logits = model.forward(inputs)

    ps = F.softmax(logits, dim=1)
    topk = ps.cpu().topk(topk)

    return (e.data.numpy().squeeze().tolist() for e in topk)
    
def process_image(image):
    preprocess = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406],
                             std=[0.229, 0.224, 0.225])])
    image = preprocess(image)
    return image
             
            
path = './image/test/*/*.JPG'
length = len(glob.glob(path))

def classPred(x, path):
    filename, Classes, Probs = [], [], []
    for i in range(x):
        im = glob.glob(path)
        probs, classes = predict2(im[i], model.to(device))
        class_names = ['Q1', 'Q2', 'Q3', 'Q4', 'Q5']
        food_names = [class_names[e] for e in classes]
        filename.append(im[i])
        output = [filename]
        output.append(classes)
        output.append(probs)
        Classes.append(classes)
        Probs.append(probs)

    return filename , Classes, Probs
  
        
filename, Classes, Probs = classPred(length, path)

file_name = []
for i in range(len(filename)):
    file_name.append(filename[i].split("/"))


quantity = []
for i in range(len(file_name)): 
    quantity.append(file_name[i][3])
   
cls_name = {'Q1': 0, 'Q2': 1, 'Q3':2, 'Q4':3, 'Q5': 4}   

labels = []
for i in range(len(quantity)):
    labels.append(cls_name[quantity[i]]) 

classes = []
for i in range(len(Classes)):
    classes.append(Classes[i][0])
    
      
for i in range(len(labels)):
    if labels[i] == Classes[i][0]:
       print('\t T :\t', filename[i])
    else:
       print('\t F :\t', filename[i])
 
                       
# confusion matrix    
print('===============================================================')            
y_true = labels
y_pred = classes
arr = confusion_matrix(y_true, y_pred)
print('ResNet Confusion Matrix')
print('---------------------------------------------------------------')
df_cm = pd.DataFrame(arr, index=['Q1', 'Q2', 'Q3', 'Q4', 'Q5'],
                  columns=['Q1', 'Q2', 'Q3', 'Q4', 'Q5'])
print(df_cm)                     


# precision, recall, f1-score, support
print('===============================================================')
target_names = ['Q1', 'Q2', 'Q3', 'Q4', 'Q5' ]
print(classification_report(y_true, y_pred, target_names=target_names))          


