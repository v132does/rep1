create or replace function it.fue_eje_rollback
(p_cod_programa in ba_programas.cod_programa%type,
 p_cod_pro_llamador in ba_programas.cod_programa%type default null
) return varchar2 is
  --- Utilizado en el lgutils para verificar si el programa debe o no realizar rollback al ser llamado
  Result varchar2(01) := 'S'; -- Debe ejecutar rollback al llamar al programa
begin
  if p_cod_programa in ('GLCUENTA','ERLOVPER','EPGARPRE') then
     result := 'N';
  end if;
  if result = 'S' then
    if p_cod_pro_llamador in ('ERREPERS') then
       result := 'N';
    end if;
  end if;
  return(Result);
end fue_eje_rollback;
/

