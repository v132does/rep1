create or replace function it.fug_val_es_numerico(p_valor in varchar2) return varchar2 is
 --Evalua si un valor enviado es numerico o no--
 v_numero number;
begin
  v_numero := TO_NUMBER(p_valor);
  return 'S';
Exception
    WHEN OTHERS then
      return 'N';
end;
/

