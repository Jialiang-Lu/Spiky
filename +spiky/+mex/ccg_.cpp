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

        // Get inputs
        const TypedArray<double> times = inputs[0];
        const TypedArray<int> marks = inputs[1];
        int nSpikes = inputs[0].getNumberOfElements();
        vector<double> times1 = vector<double>(nSpikes);
        vector<int> marks1 = vector<int>(nSpikes);
        int i = 0;
        for (auto t : times)
        {
            times1[i++] = t;
        }
        i = 0;
        for (auto m : marks)
        {
            marks1[i++] = m;
        }

        const double binSize = inputs[2][0];
        const int halfBins = inputs[3][0];
        const size_t nlhs = outputs.size();

        // Derive other constants
        size_t nBins = 1 + 2 * halfBins;
        double furthestEdge = binSize * ((double)halfBins + 0.5);

        // Count nMarks
        size_t nMarks = 0;
        for (int i = 0; i < nSpikes; i++) 
        {
            int mark = marks1[i];
            if (mark > nMarks) 
            {
                nMarks = mark;
            }
            if (mark == 0) 
            {
                getEngine()->feval(u"error",
                    0, std::vector<Array>({ factory.createScalar("No zeros allowed in marks.") }));
            }
        }

        // Allocate output array
        vector<int> count = vector<int>(nMarks * nMarks * nBins, 0);
        vector<int> pairs;
        if (nlhs > 1)
        {
            pairs = vector<int>();
        }
        int centerSpike, secondSpike, mark1, mark2, bin;
        double time1, time2;

        // Now the main program
        for (centerSpike = 0; centerSpike < nSpikes; centerSpike++) 
        {
            mark1 = marks1[centerSpike];
            time1 = times1[centerSpike];

            // Go back from centerSpike
            for (secondSpike = centerSpike - 1; secondSpike >= 0; secondSpike--) 
            {
                time2 = times1[secondSpike];

                // Check if we have left the interesting region
                if (abs(time1 - time2) > furthestEdge)
                    break;

                // Calculate bin
                bin = halfBins + (int)(floor(0.5 + (time2 - time1) / binSize));

                mark2 = marks1[secondSpike];
                count[(mark1 - 1) * nMarks * nBins + (mark2 - 1) * nBins + bin] += 1;
                if (nlhs > 1)
                {
                    pairs.push_back(centerSpike);
                    pairs.push_back(secondSpike);
                }
            }

            // Now do the same thing going forward...
            for (secondSpike = centerSpike + 1; secondSpike < nSpikes; secondSpike++) 
            {
                time2 = times1[secondSpike];

                // Check if we have left the interesting region
                if (abs(time1 - time2) > furthestEdge)
                    break;

                // Calculate bin
                bin = halfBins + (int)(floor(0.5 + (time2 - time1) / binSize));

                mark2 = marks1[secondSpike];
                count[(mark1 - 1) * nMarks * nBins + (mark2 - 1) * nBins + bin] += 1;
                if (nlhs > 1)
                {
                    pairs.push_back(centerSpike);
                    pairs.push_back(secondSpike);
                }
            }
        }

        // Set outputs
        outputs[0] = factory.createArray({nBins, nMarks, nMarks}, count.begin(), count.end(), 
            InputLayout::COLUMN_MAJOR);
        if (nlhs > 1)
        {
            outputs[1] = factory.createArray({pairs.size() / 2, 2},
                pairs.begin(), pairs.end(), InputLayout::ROW_MAJOR);
        }
    }

private:
    ArrayFactory factory;

    void checkArguments(ArgumentList inputs) 
    {
        if (inputs.size() != 4)
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Four inputs required.") }));
        }
        if (inputs[0].getType() != ArrayType::DOUBLE || inputs[1].getType() != ArrayType::INT32 ||
            inputs[2].getType() != ArrayType::DOUBLE || inputs[3].getType() != ArrayType::INT32)
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Wrong input types.") }));
        }
        if (inputs[0].getNumberOfElements() != inputs[1].getNumberOfElements())
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Times and marks must have the same length.") }));
        }
        if (inputs[2].getNumberOfElements() != 1 || inputs[3].getNumberOfElements() != 1)
        {
            getEngine()->feval(u"error",
                0, std::vector<Array>({ factory.createScalar("Bin size and half bins must be scalars.") }));
        }
    }
};