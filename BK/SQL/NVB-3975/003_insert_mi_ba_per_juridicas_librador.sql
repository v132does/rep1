-- Created on 2/6/2021 by EVER.AYALA 
declare
  i integer;
  cursor c_ba_per_jur IS
    SELECT *
      FROM ba_per_juridicas@uenodesg A
     where exists (SELECT 1
              FROM it.mi_ba_personas_librador b
             where a.cod_persona = b.cod_persona);
  v_cant number;
begin
  v_cant := 0;
  
  delete from it.mi_ba_per_juridicas_librador;
  
  FOR pj IN c_ba_per_jur LOOP
    v_cant := v_cant + 1;
    insert into it.mi_ba_per_juridicas_librador
      (cod_persona,
       raz_social,
       nom_comercial,
       naturaleza,
       fec_apertura,
       cod_ramo,
       gar_tercero,
       cap_operativo,
       cod_area)
    values
      (pj.cod_persona,
       pj.raz_social,
       pj.nom_comercial,
       pj.naturaleza,
       pj.fec_apertura,
       pj.cod_ramo,
       pj.gar_tercero,
       pj.cap_operativo,
       pj.cod_area);
    dbms_output.put_line('Cantidad; ' || v_cant || ' DOCUMENTO ' ||
                         PJ.COD_PERSONA);
  END LOOP;
  commit;
EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line(SQLERRM);
end;
