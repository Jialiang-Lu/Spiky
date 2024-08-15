#include "mex.hpp"
#include "mexAdapter.hpp"

using namespace matlab::data;
using namespace matlab::mex;

class MexFunction : public Function 
{
public:
    void operator()(ArgumentList outputs, ArgumentList inputs) 
    {
        checkArguments(inputs);

        const TypedArray<double> array = std::move(inputs[0]);
        const double target = inputs[1][0];

        int left = 0;
        int right = array.getNumberOfElements() - 1;

        if (inputs.size() > 2) 
        {
            left = static_cast<int>(inputs[2][0])-1;
        }
        if (inputs.size() > 3) 
        {
            right = static_cast<int>(inputs[3][0])-1;
        }
        if (left < 0)
            left = 0;
        if (right >= array.getNumberOfElements())
            right = array.getNumberOfElements()-1;
        if (left > right) 
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Left must be less than or equal to right.") }));
        }

        double result = static_cast<double>(binarySearch(array, target, left, right) + 1);

        outputs[0] = factory.createScalar(result);
    }

private:
    ArrayFactory factory;

    int binarySearch(const TypedArray<double>& array, double target, int left, int right) 
    {
        int result = -1;

        while (left <= right) {
            int mid = left + (right - left) / 2;

            if (array[mid] == target) 
            {
                return mid;
            }

            if (array[mid] < target) 
            {
                result = mid;
                left = mid + 1;
            } 
            else 
            {
                right = mid - 1;
            }
        }

        return result;
    }

    void checkArguments(ArgumentList inputs) 
    {
        std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr = getEngine();
        matlab::data::ArrayFactory factory;

        if (inputs.size() < 2 || inputs.size() > 4) 
        {
            matlabPtr->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Two to four input arguments required.") }));
        }
        if (inputs[0].getType() != ArrayType::DOUBLE || inputs[0].getNumberOfElements() == 0) 
        {
            matlabPtr->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Array must be a non-empty double array.") }));
        }
        if (inputs[1].getType() != ArrayType::DOUBLE || inputs[1].getNumberOfElements() != 1) 
        {
            matlabPtr->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Target must be a double scalar.") }));
        }
        if (inputs.size() > 2 && (inputs[2].getType() != ArrayType::DOUBLE || inputs[2].getNumberOfElements() != 1)) 
        {
            matlabPtr->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Left must be a double scalar.") }));
        }
        if (inputs.size() > 3 && (inputs[3].getType() != ArrayType::DOUBLE || inputs[3].getNumberOfElements() != 1)) 
        {
            matlabPtr->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Right must be a double scalar.") }));
        }
    }
};
