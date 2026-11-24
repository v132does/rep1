CREATE OR REPLACE PROCEDURE IT.PRG_VAL_OFE_CLIENTES
IS

v_cod_persona  varchar2(20);
v_fec_actual   date:= pag_cal.FU_OBT_FEC_ACTUAL(7);
v_existe        varchar2(1):='N';
v_lugar         varchar2(3000);
v_mensaje       varchar2(3000);

--Cursor de validaciones iniciales
Cursor c_ver_inicial IS
   select a.*
     from bw_ofe_clientes_tmp a
      order by a.cod_persona;
/********************
|| Proceso Principal
*********************/
BEGIN
 begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;

    for x in c_ver_inicial loop
        v_mensaje:= null;
        v_cod_persona:= x.cod_persona;
        v_lugar:='Al buscar si existe cliente';
        begin
                select  'S'
                   into v_existe
                   from ba_personas a
                     where a.cod_persona= x.cod_persona
                         and rownum=1;

        exception
          when no_data_found then
            raise_application_error(-20000,'No se encuentra cliente : '||x.cod_persona);
         when others then
            raise_application_error(-20000,'Error al Buscar cliente: '||x.cod_persona||'-'||sqlerrm );
        end;
        v_lugar:='Al validar Inicio';
        if x.inicio is null then
          raise_application_error(-20000,'Debe Ingresar Inicio (S o N)');
        elsif x.inicio not in ('S','N') then
          raise_application_error(-20000,'Debe Ingresar Inicio S -Login  o N - Logout');
        end if;


        v_lugar:='Al validar Fecha de Inicio:'||x.fec_inicio;
        if x.fec_inicio is not null then
          if X.fec_inicio< v_fec_actual then
          raise_application_error(-20000,'La fecha de inicio debe ser mayor o igual a hoy');
          end if;
        end if;
        v_lugar:='Al validar Fecha de Fin'||x.fec_fin;
        if x.fec_fin is not null then
          if x.fec_inicio is not null then
            if  X.fec_inicio >  X.fec_fin then
               raise_application_error(-20000,'La fecha de fin debe ser mayor a la fecha de inicio');
            end if;
          end if;
        end if;

        v_lugar:='Al validar producto';
        if x.producto is null then
          raise_application_error(-20000,'Debe ingresar producto');
        else
          v_existe:='N';
          begin
            select 'S'
                 into v_existe
                 from ba_cod_referencias r
                where r.dominio = 'TIP_OFE_CLIENTE'
                  and upper(r.val_minimo) = upper(x.producto);
          exception
            when no_data_found then
               raise_application_error(-20000,'No existe producto:'|| x.producto);
            when others then
               raise_application_error(-20000,'error al buscar producto:'|| x.producto||' '||sqlerrm);
          end;

        end if;

        v_lugar:='Al validar mensaje';
        if x.mensaje is not null and length(x.mensaje)> 3000  then
          raise_application_error(-20000,'Longitud Máxima de mensaje: 3000');
        end if;

        v_lugar:='Al url imagen';
        if x.url_imagen is not null then
          if length(x.mensaje)> 3000  then
             raise_application_error(-20000,'Longitud Máxima de url: 3000');
          end if;
        end if;
        v_lugar:='Al obtener mensaje';


        PRG_IMP_OFERTAS(x.cod_persona,x.producto,x.mensaje, v_mensaje);
        --reemplazamos xx por ;
        v_lugar:='Al reemplazar';
        v_mensaje:= replace(v_mensaje, 'XX',';');
        v_mensaje:= replace(v_mensaje, 'xx',';');
        v_lugar:='Al borrar de Tabla permanente';
        delete from bw_ofe_clientes w where w.cod_persona= x.cod_persona and w.inicio=x.inicio;

        v_lugar:='Al insertar en Tabla permanente';
        BEGIN
          insert into bw_ofe_clientes (COD_PERSONA,PRODUCTO,CANTIDAD,INICIO,FEC_INICIO,FEC_FIN,
           MENSAJE,URL_IMAGEN,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION)
          values(v_cod_persona,x.PRODUCTO,x.CANTIDAD,x.INICIO,x.FEC_INICIO,x.FEC_FIN,
           v_mensaje,x.URL_IMAGEN,user,sysdate,user,sysdate);
        EXCEPTION
          WHEN OTHERS THEN
             raise_application_error(-20000,'Error:' || sqlerrm);
        END;

   end loop;

EXCEPTION
  WHEN OTHERS THEN
     raise_application_error(-20000,'Error al validar.: Cliente:'||v_cod_persona||' Lugar:'||v_lugar||'-'||SQLERRM);
END;
/

