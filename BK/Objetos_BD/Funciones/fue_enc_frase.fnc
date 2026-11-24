create or replace function it.fue_enc_frase(pfrase in varchar2) return varchar2 is
  Result varchar2(2000) := ltrim(pfrase);
  l number(3) := length(Result);
  mitad number(3) := trunc(l/2);
  xx number(3);
  cadena varchar2(10) := '6850394217';
begin
  for i in 1..mitad
  loop
    Result := substr(Result,1,i-1)||
              substr(Result,l-i+1,1)||
              substr(Result,i+1,(l-i)-(i+1)+1)||
              substr(Result,i,1)||
              substr(Result,l-i+2);
  end loop;
  for i in 1..l
  loop
     xx := to_number(substr(cadena,mod(i,10) + 1,1));
     Result := substr(Result,1,i-1) ||
               chr(158 - ascii(substr(Result,i,1)) + xx)||
               substr(Result,i+1);
  end loop;
  
  return(Result);
end fue_enc_frase;
/

