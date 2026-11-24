CREATE OR REPLACE FUNCTION IT.FUE_VER_DOCUMENTADO
 (P_COD_PROGRAMA IN VARCHAR2
 )
 RETURN varchar2
 IS
v_result           varchar2(1) := 'N';--Valores posibles S/N
begin
  begin
    select 'S'
      into v_result
      from ba_man_detalles b
     where b.cod_programa = p_cod_programa
       and rownum = 1;
  exception
     when no_data_found then
       begin
           select 'S'
             into v_result
             from ba_man_detalles b
            where instr(b.detalle,'['||p_cod_programa||']') > 0
              and rownum = 1;
       exception
          when others then
              v_result := 'N';
       end;
  end;
  return v_result;
End;
/

