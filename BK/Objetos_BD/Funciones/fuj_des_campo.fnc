create or replace function it.FUJ_DES_CAMPO
  (p_campo        in varchar2,
   p_valor        in varchar2,
   p_val_posibles in varchar2 default null,
   p_tip_dato     in varchar2 default null)
 return varchar2 is
begin
   --formato: [<NOM_CAMPO>~<VALOR>~<VALORES_POSIBLES>~<TIPO_DE_DATO>]
   if p_tip_dato is not null then
      return '[' ||
          trim(upper(p_campo))||'~'||
          nvl(trim(p_valor),'X')||'~'||
          nvl(p_val_posibles,'X')||'~'||
          p_tip_dato||
          ']'; 
   elsif p_val_posibles is not null then
      return '[' ||
          trim(upper(p_campo))||'~'||
          nvl(trim(p_valor),'X')||'~'||
          nvl(p_val_posibles,' ')||
          ']'; 
   else
      return '[' ||
          trim(upper(p_campo))||'~'||
          nvl(trim(p_valor),'X')||
          ']'; 
   end if;
end;
/

