#include <iostream>
#include <opencv2/opencv.hpp>
#include <opencv2/features2d.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/calib3d/calib3d.hpp>
#include <opencv2/videoio.hpp>
#include <vector>
#include <fstream>
#include <sstream>
#include <string>
#include <iomanip>
#include "yuv2bgr.hpp"

using namespace cv;
using namespace std;

// Define paths
string pathImages = "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/ImageRecApp/ImagesQuery";
string pathMovies = "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/ImageRecApp/MoviesQuery";
string localFeaturesFilePath = "features.yml";
vector<Mat> desList;
Mat mostRecentDes;
int mostRecentId = -1;
Size imgSize = Size(320, 320);

// Small threshold means a small feature set
Ptr<ORB> orb = ORB::create(500, 1.2f, 8, 31, 0, 2, ORB::HARRIS_SCORE, 31);

// Set the threshold of minimum features detected to give a positive, around 20 to 30
int thresh = 30;
int sameImageThresh = 30;

// Function to save features
void saveFeatures(vector<Mat>& images_features, vector<string>& images_name) {
    cout << "Saving features for next time use" << endl;
    FileStorage fs(localFeaturesFilePath, FileStorage::WRITE);
    write(fs, "images_features", images_features);
    write(fs, "images_name", images_name);
    fs.release();
}


// Function to check if features need to be computed
bool needToComputeFeatures( vector<string>& images_name) {
    // Descriptor re-computation flag
    bool shouldComputeFeature = false;

    FileStorage fs(localFeaturesFilePath, FileStorage::READ);
    if (fs.isOpened()) {
        // cout<<"Features file is opened"<<endl;
        // cout<<"Extracting image_names"<<endl;
        FileNode fn = fs["images_name"];
        if (!fn.empty()) {
            vector<string> images_name_from_file;
            read(fn, images_name_from_file);
            // cout<<"Found "<<images_name_from_file.size()<<" image names"<<endl;

            // ensure that all paths of images in images_name are in the features file
            // if not, set the descriptor re-computation flag to true (i.e. re-compute the descriptors fro each image)
            for(int i = 0; i< images_name.size(); i++) {
                auto searchResult = find(images_name_from_file.begin(), images_name_from_file.end(), images_name[i]);
                if(searchResult == images_name_from_file.end() ){
                    cout<<"Image name not found, please re-compute the feature descriptors"<<endl;
                    shouldComputeFeature = true;
                    break;
                }
            }
            shouldComputeFeature = images_name != images_name_from_file;
        } else {
            cout<<"File features.yml is empty"<<endl;
            shouldComputeFeature = true;
        }
        fs.release();
    } else {
        cout<<"Unable to open features file. Please re-compute and save the features"<<endl;
        shouldComputeFeature = true;
    }
    return shouldComputeFeature;
}


// Function to find matching points in the images
vector<Mat> findDes( vector<Mat>& images, vector<string>& images_name) {
    // vector<Mat> desList;
    // vector<string> images_name_from_file;
    bool shouldComputeFeature = needToComputeFeatures(images_name);

    /// If features need to be re-computed, 
    // Re-compute the features and store them in the features file
    if (shouldComputeFeature) {
        cout << "Start computing features" << endl;
        for (const Mat& img : images) {
            // Resize image before fetching features
            Mat resizedImg;
            resize(img, resizedImg,imgSize);
            vector<KeyPoint> kp;
            Mat des;
            orb->detectAndCompute(resizedImg, noArray(), kp, des);
            desList.push_back(des);
        }
        // Save these features for next time with the images name list
        saveFeatures(desList, images_name);
    }
    // If features do not need to be re-computed,
    // Simply extract the features from the features file
    else {
        cout << "Start reading features from file" << endl;
        FileStorage fs(localFeaturesFilePath, FileStorage::READ);
        if (fs.isOpened()) {
            cout<<"**Features file is opened"<<endl;
            cout<<"**Extracting image_names"<<endl;
            read(fs["images_features"], desList);
            fs.release();
        }

    }

    return desList;
}


// load image descriptors for future use
void _loadDescriptors(char** imagePathsPrimitive, char* featuresFilePath, int pathCount) {
localFeaturesFilePath = featuresFilePath;
vector<string> imagePaths;

///populate the image paths vector
for(int i = 0; i < pathCount; i++) {
    imagePaths.push_back(imagePathsPrimitive[i]);
}

vector<Mat> images;
for(int idx= 0; idx < imagePaths.size(); idx++){
    cout << idx + 1 <<" "<<imagePaths[idx]<<endl;
    Mat imgCur = imread(imagePaths[idx], IMREAD_GRAYSCALE);
    if (!imgCur.empty()) {
        images.push_back(imgCur);
    }
}
    // Start finding features
cout << "Start finding features" << endl;
findDes(images, imagePaths);
cout<<"Found "<<desList.size()<<" descriptions"<<"   "<<"Shape "<<desList[0].size();
}


// Function to find the matching image
int findID( Mat& img) {

    //Resize the image to 320 x 320
    resize(img, img, imgSize);

    vector<KeyPoint> kp2;
    Mat des2;
    orb->detectAndCompute(img, noArray(), kp2, des2);

    // save the descriptor of the incomming image in mostRecentDes for future comparisons
    mostRecentDes = des2;

    BFMatcher bf(NORM_HAMMING);
    int bestMatchIndex = -1;
    int maxGoodMatchCount = 0;
    bf.add(des2);


    /// Match the current descriptor against each and every other descriptor in the descriptor list
    for (int i = 0; i < desList.size(); i++) {
        Mat des = desList[i];
        vector<vector<DMatch>> matches;
        int goodMatchesCount = 0;
        bf.knnMatch(des,matches,2);
        for (size_t j = 0; j < matches.size(); j++) {
            //Guage the goodness of a match using the Lowe's criterion
            if (matches[j][0].distance < 0.75 * matches[j][1].distance) {
                goodMatchesCount++;
            }
        }


        if(goodMatchesCount > thresh && goodMatchesCount > maxGoodMatchCount ) {
            maxGoodMatchCount = goodMatchesCount;
            bestMatchIndex =  i;
        }

    }

    ///set mostRecent ID
    mostRecentId = bestMatchIndex;

    return bestMatchIndex;
}


// Quickly checks if the incomming image is identical to the previous image
bool isSameAsLatest(Mat& img) {

    //Resize the image to 320 x 320
    resize(img, img, imgSize);

    if(mostRecentDes.empty()) return false;

    vector<KeyPoint> kp2;
    Mat des2;
    orb->detectAndCompute(img, noArray(), kp2, des2);

    BFMatcher bf(NORM_HAMMING);
    bf.add(des2);
    vector<vector<DMatch>> matches;
    int goodMatchesCount = 0;
    
    bf.knnMatch(mostRecentDes,matches,2);
    for (size_t j = 0; j < matches.size(); j++) {
        if (matches[j][0].distance < 0.75 * matches[j][1].distance) {
            goodMatchesCount++;
        }
    }

    //Return true if the number of good matches with the previous image exceeds the predefined threshold
    if(goodMatchesCount > sameImageThresh) {
        return true;
    }

    return false;

}


int _findBestMatchMat(Mat& imgGray) {
    if(isSameAsLatest(imgGray) == true) {
        return mostRecentId;
    }else {
        return findID(imgGray);
    }
}


int _findBestMatchYUV(
    uint8_t* plane0Bytes, uint8_t* plane1Bytes, uint8_t* plane2Bytes,
	int width, int height,
	int bytesPerRowPlane0 = 1, int bytesPerRowPlane1 = 2, int bytesPerRowPlane2 = 2,
	int bytesPerPixelPlane0 = 1, int bytesPerPixelPlane1 = 2, int bytesPerPixelPlane2 = 2
) {
        /// Convert image from YUV format to RGB format
        Mat image = yuv2bgr(
                        plane0Bytes, plane1Bytes, plane2Bytes,
                        width, height, 
                        bytesPerRowPlane0, bytesPerRowPlane1, bytesPerRowPlane2,
                        bytesPerPixelPlane0, bytesPerPixelPlane1, bytesPerPixelPlane2);

        /// Covert the image into grayscale
        cvtColor(image, image, COLOR_BGR2GRAY);

        return _findBestMatchMat(image);
}


bool _matchImages(string img1Path, string img2Path) {
            Mat img1 = imread(img1Path, IMREAD_GRAYSCALE);
            imshow("image 1", img1);
            Mat img1Resized;
            resize(img1, img1Resized, imgSize);
            vector<KeyPoint> kp1;
            Mat des1;
            orb->detectAndCompute(img1Resized, noArray(), kp1, des1);

            Mat img2 = imread(img2Path, IMREAD_GRAYSCALE);
            imshow("image 2", img2);
            Mat img2Resized;
            resize(img2, img2Resized, imgSize);
            vector<KeyPoint> kp2;
            Mat des2;
            orb->detectAndCompute(img2Resized, noArray(), kp2, des2);


            BFMatcher bf(NORM_HAMMING);
            vector<vector<DMatch>> matches;
            vector<Mat> queryDescriptors = {des1, des2};
        
            bf.add(des1);
            bf.knnMatch(des2, matches, 2);

            vector<DMatch> goodMatches;

            for (size_t i = 0; i < matches.size(); i++) {
                if (matches[i][0].distance < 0.75 * matches[i][1].distance) {
                    goodMatches.push_back(matches[i][0]);
                }
            }

            cout<<"Total matches: "<<matches.size()<<endl;
            cout<<"Total good matches: "<<goodMatches.size()<<endl;

            Mat imgMatches;
            drawMatches(img1Resized, kp1, img2Resized, kp2, goodMatches, imgMatches);

            imshow("Matches", imgMatches);

            waitKey(0);
            return false;

}


// int main() {

//         cout<<"Is MostRecentDes empty?  "<<mostRecentDes.empty()<<endl;
//         cout<<"Most recent ID state: "<<mostRecentId<<endl;
//         // return 0;


//     // List Images and Print out their Names and how many there are in the Folder
//     char* imagePaths[] = {
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/001.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/002.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/003.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/004.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/005.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/006.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/007.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/008.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/009.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/010.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/011.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/012.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/013.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/014.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/015.jpeg",
//         };

//     char* testImagePaths[] = {
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/001.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/002.jpeg",
//         "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/ImageMatchApp/ImageMatchApp/Database/test/003.jpeg"
//         };

//     string imagePath1 = "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/meseum_item_matcher_c++/cattle/train/003.png";
//     string imagePath2 = "C:/Users/SMARTECH/Desktop/ME/freelance/off_market_places/jancryzan/meseum_item_matcher_c++/cattle/test/003.png";

//     // _matchImages(testImagePaths[0], testImagePaths[0]);
//     // return 0;


//     // Load descriptors the first time the application is run
//     _loadDescriptors(imagePaths, 5);

//     /// if the previous des

//     Mat testImage = imread(imagePaths[2], IMREAD_GRAYSCALE);
//     if(testImage.empty()) {
//         cout<<"Invalid image found "<<testImagePaths[0]<<endl;
//         return 0;
//     }
//     resize(testImage, testImage, Size(320, 320));
    
//     ///Compare testImage with images in the database
//     int id = findID(testImage);
//     cout<<"***Matches image ID: "<<id<<endl;

//     // imshow("Result: " + to_string(id), testImage);
//     // waitKey(0);

//     // destroyAllWindows();

//     return 0;


// }
