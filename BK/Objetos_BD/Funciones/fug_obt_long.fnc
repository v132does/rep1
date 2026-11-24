CREATE OR REPLACE FUNCTION IT.FUG_OBT_LONG
/* Funcion para extraer del campo Long */
  return varchar2 is
  cursor consultas
   is select mensaje, respuesta, usu_insercion, fec_insercion
     FROM log_mensajeria 
     where mensaje like 'TCA#T#%';
v_det_sql varchar2(4000);
begin
   for cc in consultas loop
       v_det_sql := substr(upper(cc.respuesta),1,4000);
       insert into log_mensajeria_bkp (mensaje, respuesta, usu_insercion, fec_insercion)
              values (cc.mensaje, v_det_sql, cc.usu_insercion, cc.fec_insercion );
              
              commit ;
       v_det_sql := null ;
   end loop;
   return null;
end;
/

