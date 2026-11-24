CREATE OR REPLACE FUNCTION IT.FUG_OBT_PRO_CIE_ENCURSO RETURN VARCHAR2 IS
--Variables--
 v_hor_ini_10 varchar2(8);
 v_hor_fin_10 varchar2(8);
 v_hor_ini_11 varchar2(8);
 v_hor_fin_11 varchar2(8);
 v_cod_pro_encurso ge_procesos.cod_proceso%type;

BEGIN
  --DESOPIMI-64 / Ajustes para sacar fuera de la ventana de integridad--
  --Ya no depende del estado del modulo - Depende de la evaluacion del proceso en curso--
  --Inicializar Variables--
  v_hor_ini_10 := null;
  v_hor_fin_10 := null;
  v_hor_ini_11 := null;
  v_hor_fin_11 := null;

  --Traer datos de procesos --10-Inicio, o 11-Cierre--
  select z.hor_inicio, z.hor_fin
    into v_hor_ini_10, v_hor_fin_10
    from ge_procesos z
   where z.cod_proceso = 10; --Inicio--
  select z.hor_inicio, z.hor_fin
    into v_hor_ini_11, v_hor_fin_11
    from ge_procesos z
   where z.cod_proceso = 11; --Cierre--
  
  --Evaluacion de Procesos --10-Inicio, o 11-Cierre--
  if ((v_hor_ini_10 is not null) and (v_hor_fin_10 is null) and (v_hor_ini_11 is null) and (v_hor_fin_11 is null)) then
     v_cod_pro_encurso := 10; --10-Inicio--
  elsif ((v_hor_ini_11 is not null) and (v_hor_fin_11 is null) and (v_hor_ini_10 is not null) and (v_hor_fin_10 is not null)) then
     v_cod_pro_encurso := 11; --11-Cierre--
  else
     v_cod_pro_encurso := null;
  end if;
  return v_cod_pro_encurso;
exception
  when others then
       raise_application_error(-20000,'Error en FUG_OBT_PRO_CIE_ENCURSO - '||sqlerrm);
END;
/

