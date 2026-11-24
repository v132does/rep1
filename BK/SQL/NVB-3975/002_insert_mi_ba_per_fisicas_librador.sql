-- Created on 3/6/2021 by EVER.AYALA 
declare
  i integer;
  CURSOR c_per_fis IS
    SELECT *
  FROM ba_per_fisicas@uenodesg T
 where exists (select 1
                 from it.mi_ba_personas_librador p
                where t.cod_persona = p.cod_persona);
         
  v_cod_persona it.mi_ba_per_fisicas_librador.cod_persona%TYPE;
  
begin
  
  delete from it.mi_ba_per_fisicas_librador;
  
  FOR pf IN c_per_fis LOOP
    
    v_cod_persona := pf.cod_persona;
    
    insert into it.mi_ba_per_fisicas_librador
      (cod_persona,
       pri_nombre,
       pri_apellido,
       est_civil,
       cod_sexo,
       cod_niv_estudio,
       cod_pai_nacionalidad,
       seg_nombre,
       seg_apellido,
       fec_nacimiento,
       can_hijos,
       cod_profesion,
       COD_TIP_VIVIENDA,
       COD_CIU_NACIMIENTO)
    values
      (pf.cod_persona,
       nvl(pf.pri_nombre, 'MIGRA'),
       nvl(pf.pri_apellido, 'MIGRA'),
       pf.est_civil,
       pf.cod_sexo,
       pf.cod_niv_estudio,       
       pf.cod_pai_nacionalidad,
       pf.seg_nombre,
       pf.seg_apellido,
       pf.fec_nacimiento,
       to_number(substr(pf.can_hijos, 1, 2)),
       pf.cod_profesion,
       decode(pf.cod_tip_vivienda,0,4,null,4,pf.cod_tip_vivienda),
       pf.cod_ciu_nacimiento);
       
    IF SQL%NOTFOUND THEN
      RAISE_APPLICATION_ERROR(-20011, 'cod persona ' || v_cod_persona || SQLERRM);
    END IF;
    
    commit;  
  END LOOP;
  commit;
exception
  when others then
    RAISE_APPLICATION_ERROR(-20000,
                            'cod persona ' || v_cod_persona || ' ' ||
                            SQLERRM);
end;
