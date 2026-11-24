create or replace package it.IDAutomation as

function Postnet(p_data_to_encode    varchar2,
                 p_return_type       number    default 0) return varchar2;
/**************************************************************************
** Postnet       will return the properly formatted string for a Postnet **
** barcode.                  **
** Enter a single string of Zip, Zip + 4 or Zip + 4 + Delivery Point.    **
** specification string.                                                 **
** Parameters : p_data_to_encode : Data to be encoded                    **
**              p_return_type    : 0 - String to used with barcode font  **
**                                 1 - Human readable string with start  **
**                                     and end characters                **
**                                 2 - Check digit only                  **
***************************************************************************/

function I2of5  (p_data_to_encode    varchar2) return varchar2;
/***************************************************************************
** I2of5 will return the properly formatted string for a Interleave 2 of 5**
** barcode.                                                               **
** This function also "interleaves" numbers into pairs for high density   **
** without check digits.                                                  **
** specification string.                                                  **
** Parameters : p_data_to_encode : Data to be encoded                     **
****************************************************************************/

function I2of5Mod10  (p_data_to_encode    varchar2,
                      p_return_type       number  default 0) return varchar2;
/***************************************************************************
** I2of5 will return the properly formatted string for a Interleave 2 of 5**
** barcode with a Mod10 check digit                                       **
** This function also "interleaves" numbers into pairs for high density   **
** without check digits.                                                  **
** specification string.                                                  **
** Parameters : p_data_to_encode : Data to be encoded                     **
**              p_return_type    : 0 - String to used with barcode font   **
**                                 1 - Human readable string with start   **
**                                     and end characters                 **
**                                 2 - Check digit only                   **
****************************************************************************/

function Code128(p_data_to_encode    varchar2,
                 p_return_type       number    default 0) return varchar2;
/***************************************************************************
** Code128 will return the properly formatted string for a Code128        **
** barcode using the A, B, or C Specification                             **
** If you are not sure which Code 128 set is for your application, then   **
** use this one. This is a "Code 128 Auto" function that will             **
** automatically encode any data from ASCII 0 to ASCII 127. It will       **
** automatically switch to character set C for numbers also.              **
** To encode alpha-numeric UCC/EAN-128, ASCII 202 or character E is       **
** entered as the FNC1 before each AI. For example, the UCC number of     **
** (8100)712345(21)12WH5678 should be entered as: E8100712345E2112WH5678. **
** Parameters : p_data_to_encode : Data to be encoded                     **
**              p_return_type    : 0 - String to used with barcode font   **
**                                 1 - Human readable string with start   **
**                                     and end characters                 **
**                                 2 - Check digit only                   **
****************************************************************************/

function Code128A (data_to_encode    VARCHAR2) return VARCHAR2;
/********************************************************************************************
** This function will provide a string formatted for alpha-numeric values for Code 128A    **
** Parameters                                                                              **
** data_to_encode  : String that will be encoded without start and stop, checkdigit        **
**                   characters                                                            **
** Return Value                                                                            **
** start_character + data_to_encode + check_digit + stop_character                         **
*********************************************************************************************/

function Code128B (data_to_encode    VARCHAR2) return VARCHAR2;
/********************************************************************************************
** This function will provide a string formatted for alpha-numeric values for Code 128B    **
** Parameters                                                                              **
** data_to_encode  : String that will be encoded without start and stop, checkdigit        **
**                   characters                                                            **
** Return Value                                                                            **
** start_character + data_to_encode + check_digit + stop_character                         **
*********************************************************************************************/

function Code128C (data_to_encode    NUMBER) RETURN VARCHAR2;
/********************************************************************************************
** This function will provide a string formatted for numeric only values for Code 128C     **
** Parameters                                                                              **
** data_to_encode  : Value that will be encoded without start and stop, checkdigit         **
**                   characters                                                            **
** Return Value                                                                            **
** start_character + data_to_encode + check_digit + stop_character                         **
*********************************************************************************************/

function Code39Mod43(p_data_to_encode    varchar2,
                     p_return_type       number    default 0) return varchar2;
/****************************************************************************
** Code39Mod43 will return the properly formatted string for a Code39Mod43 **
** barcode using the A, B, or C Specification                              **
** Parameters : p_data_to_encode : Data to be encoded                      **
**           p_return_type    : 1 - String to used with barcode font    **
**                   2 - Human readable string with start    **
**                       and end characters                  **
**                   3 - Check digit only                    **
****************************************************************************/

function UPCa  (p_data_to_encode    varchar2) return varchar2;
/***************************************************************************
** UPCa will return the properly formatted string for a UPCa              **
** barcode.                                                               **
** specification string.                                                  **
** Parameters : p_data_to_encode : Data to be encoded                     **
****************************************************************************/

function EAN8 (p_data_to_encode    varchar2) return varchar2;
/***************************************************************************
** EAN8 will return the properly formatted string for an EAN8 barcode     **
** This function only accepts 7 digits                                    **
** Parameters : p_data_to_encode : Data to be encoded                     **
****************************************************************************/

function EAN13 (p_data_to_encode    varchar2) return varchar2;
/***************************************************************************
** EAN13 will return the properly formatted string for an EAN8 barcode     **
** This function only accepts 12 digits                                   **
** Parameters : p_data_to_encode : Data to be encoded                     **
****************************************************************************/

end;
/

