create or replace function it.fug_obt_cod_barra(p_numero in varchar2) return varchar2 is

/********************************************************************************************
** This function will provide a string formatted for numeric only values for Code 128C     **
** Parameters                                                                              **
** p_numero  : Value that will be encoded without start and stop, checkdigit         **
**                   characters                                                            **
** Return Value                                                                            **
** start_character + p_numero + check_digit + stop_character                         **
*********************************************************************************************/


  p_numero_char    varchar2(1000) := null;
  check_digit_char       varchar2(1)    := null;
  check_digit            number         := null;
  start_character        varchar2(1)    := chr(0205);
  stop_character         varchar2(1)    := chr(0206);

  current_value          number         := null;
  encoded_string         varchar2(1000) := null;

  -- Calcuation variables
  weight_value           number         := 1;
  weight_total           number         := 105;

  function fu_ver_numero(p_string varchar2) return boolean
  /****************************************************************
  ** This function will return true if the character is a number **
  ** else return false                                           **
  ****************************************************************/
  is

  begin

  for i in 1..length(p_string)
  loop
    if substr(p_string, i, 1) not in ('1','2','3','4','5','6','7','8','9','0') then
      return false;
    end if;
  end loop;
  return true;  -- All the characters are numbers
  end;
  
begin

  -- Only keep numbers and remove dashes
  for i in 1..length(p_numero)
  loop
    if fu_ver_numero(substr(p_numero,i,1)) then p_numero_char := p_numero_char || substr(p_numero,i,1); end if;
  end loop;

  -- The string must be an even length, if not append a zero to the beginning of it.
  if mod(length(p_numero_char),2) = 1 then
    p_numero_char := lpad(p_numero_char,length(p_numero_char)+1,'0');
  end if;

  for i in 1..length(p_numero_char)
  loop
    if mod(i,2) = 1 then  -- skep every second value
      current_value := to_number(substr(p_numero_char, i, 2));
    if current_value < 95 and current_value > 0 then
      encoded_string := encoded_string || chr(current_value + 32);
    elsif  current_value >= 95  then
      encoded_string := encoded_string || chr(current_value + 100);
    elsif current_value = 0 then
      encoded_string := encoded_string || chr(194);
      end if;

    -- Calculate the check digit
    current_value := current_value * weight_value;
    weight_total := weight_total + current_value;
    weight_value := weight_value + 1;
  end if;
  end loop;

  -- Get the check digit value
  check_digit := mod(weight_total,103);

  -- Get the corresponding character from the check_digit
  if check_digit < 95 and check_digit > 0 then
    check_digit_char := chr(check_digit + 32);
  elsif  check_digit >= 95 then
    check_digit_char := chr(check_digit + 100);
  elsif check_digit = 0 then
  check_digit_char := chr(194);
  end if;

  return start_character || encoded_string || check_digit_char || stop_character;

end fug_obt_cod_barra;
/

