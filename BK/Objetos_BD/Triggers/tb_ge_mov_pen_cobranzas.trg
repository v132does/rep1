CREATE OR REPLACE TRIGGER IT.TB_GE_MOV_PEN_COBRANZAS
  before insert on ge_mov_pen_cobranzas
  for each row
declare

  -- local variables here
begin
   if inserting then
      if :new.cod_movimiento is null then
         --- Generar codigo de movimiento
         select s_cod_movimiento.nextval into :new.cod_movimiento from dual;
      end if;
   end if;
end TB_GE_MOV_PEN_COBRANZAS;
/

