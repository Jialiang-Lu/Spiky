#include "mex.hpp"
#include "mexAdapter.hpp"

using namespace matlab::data;
using namespace matlab::mex;
using namespace std;

class MexFunction : public Function 
{
public:
    void operator()(ArgumentList outputs, ArgumentList inputs) 
    {
        checkArguments(inputs);

        const TypedArray<double> array = inputs[0];
        const TypedArray<double> intervals = inputs[1];
        const int n = array.getNumberOfElements();
        const size_t nIntervals = intervals.getNumberOfElements() / 2;
        vector<double> array1 = vector<double>(n);
        vector<double> intervals1 = vector<double>(nIntervals * 2);
        int i = 0;
        for (auto a : array)
        {
            array1[i++] = a;
        }
        i = 0;
        for (auto p : intervals)
        {
            intervals1[i++] = p;
        }

        const bool rightClose = inputs.size() == 3 ? static_cast<bool>(inputs[2][0]) : false;
        //TypedArray<double> indices = factory.createArray<double>({nIntervals, 1});
        //TypedArray<double> counts = factory.createArray<double>({nIntervals, 1});
        vector<double> indices = vector<double>(nIntervals);
        vector<double> counts = vector<double>(nIntervals);
        int index = 0;
        int next;
        for (int i = 0; i < nIntervals; i++)
        {
            double t0 = intervals1[i];
            double t1 = intervals1[nIntervals + i];
            for (; index < n && array1[index] < t0; index++);
            indices[i] = static_cast<double>(index + 1);
            next = index;
            if (rightClose)
                for (; next < n && array1[next] <= t1; next++);
            else
                for (; next < n && array1[next] < t1; next++);
            counts[i] = static_cast<double>(next - index);
        }
        outputs[0] = factory.createArray({ nIntervals, 1 }, indices.begin(), indices.end());
        outputs[1] = factory.createArray({ nIntervals, 1 }, counts.begin(), counts.end());
    }

private:
    ArrayFactory factory;

    void checkArguments(ArgumentList inputs) 
    {
        if (inputs.size() < 2 || inputs.size() > 3)
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Wrong number of input arguments.") }));
        }
        if (inputs[0].getType() != ArrayType::DOUBLE || inputs[1].getType() != ArrayType::DOUBLE) 
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Input arguments must be of type double.") }));
        }
        if (inputs[1].getDimensions()[1] != 2)
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Intervals must be a 2-column array.") }));
        }
        if (inputs.size() == 3 && inputs[2].getType() != ArrayType::LOGICAL)
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("LeftClose must be of type logical.") }));
        }
    }
};