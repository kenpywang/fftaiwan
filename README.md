# Replication of Fama-French Factors based on Taiwanese Data

## Description

- Purpose: I create this project to replicate the market, SMB, and HML factors introduced by Fama and French (1993) using Taiwanese data. 
- Brief Instruction: You can run the master.do to get the factors based on Taiwanese data. 

### Data and Code Availability Statement

- Data Sources: Taiwan Economic Journal (TEJ)
- Source Codes: [GitHub repository](https://github.com/kenpywang/)

### Machine Requirements

- Operating System: Windows 10
- CPU: intel CORE i7 8th Gen
- Memory: 16GB

### Instructions for Data Preparation and Analysis

Notes:
- The program genbp.do generates breakpoints of market equities and book-to-market ratios.
- The program genfact.do uses the breakpoint data and other raw data from the TEJ to generate factors. 
- You can run the master.do, which shows the pipeline of the factor construction, to conduct the genbp.do and genfact.do.
- This project is part of my research project ecosystem. I share it because it may be useful for those interested in replicating Fama-French factors using data from different countries.  
- Since I am busy, I did not add sufficient comments in my codes. Therefore, feel free to email me via [kenpywang@gmail.com](mailto:kenpywang@gmail.com) if you still cannot understand some parts of the codes after searching on the Internet or talking with AI chatbots, such as the ChatGPT. 

## References

### Bibliography
- Fama, Eugene F., and Kenneth R. French. 1993. “Common Risk Factors in the Returns on Stocks and Bonds.” Journal of Financial Economics 33 (1): 3–56. https://doi.org/10.1016/0304-405X(93)90023-5.

### Others
- [Source of this README Template](https://github.com/social-science-data-editors/template_README/blob/42894e3a09ce85ee4faafd790cf55467bca18307/README.md)
- [Complete Version of the README Template](https://zenodo.org/record/7293838#.Y79UIBVBxZV)
- [AEA Data Editor](https://aeadataeditor.github.io/)