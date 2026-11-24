CREATE OR REPLACE FUNCTION IT.FUC_VER_CHE_REMITIDOS
 (P_FECHA IN DATE
 ,P_COD_USUARIO IN CC_CHE_REMITIDOS.USU_INSERCION%TYPE
 )
 RETURN VARCHAR2
 IS
v_salida varchar2(4000);

cursor cheques is
  select count(*),cod_banco,nro_cheque
    from CC_CHE_REMITIDOS
   where fecha = p_fecha
     and usu_insercion = p_cod_usuario
   group by cod_banco, nro_cheque
  having count(*) > 1;

begin
   --verificar si existen duplicados en cc_che_remitidos
   for reg in cheques loop
      --verificar tipo de msj a devolver
      v_salida := 'Existen registros duplicados: Bco. '||reg.cod_banco||'. Cheq. '||reg.nro_cheque;
      exit;
   end loop;
      
  return(v_salida);
exception
  when others then
     raise_application_error(-20000,'FUC_VER_CHE_REMITIDOS '||sqlerrm);
end;
/

