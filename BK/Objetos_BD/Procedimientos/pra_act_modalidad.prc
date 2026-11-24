CREATE OR REPLACE PROCEDURE IT.pra_act_modalidad(p_persona      in varchar2 default null,
                                                 p_nro_cuenta   in varchar2 default null,
                                                 p_modalidad_origen     in number default 334,
                                                 p_modalidad_destino    in number default 31) IS
   v_cod_modalidad   number;
   v_nro_cuenta      varchar2(15);
   v_modalidad_dest  number;
   
   CURSOR v_cursor IS
        SELECT c.nro_cuenta,
               c.cod_modalidad,
               FUG_OBT_PARADICIONAL(c.nro_cuenta, 'CTA_CAM_MODALIDAD')
          FROM ah_cta_vistas   c,
               ge_cta_clientes cl,
               ge_clientes     cc
         WHERE c.nro_cuenta = cl.nro_cuenta
           AND c.cod_modulo = cl.cod_modulo
           AND c.cod_modalidad = cl.cod_modalidad
           AND c.cod_oficina = cl.cod_oficina
           AND cl.relacion = 'P'
           AND c.estado not in ('C', 'P')
           AND cl.cod_persona = cc.cod_persona
           and FUG_OBT_PARADICIONAL(c.nro_cuenta, 'CTA_CAM_MODALIDAD') is not null
           and FUG_OBT_PARADICIONAL(c.nro_cuenta, 'CTA_CAM_MODALIDAD') != p_modalidad_origen
           and c.cod_modalidad = nvl(p_modalidad_origen, c.cod_modalidad)
           and cl.cod_persona = nvl(p_persona, cl.cod_persona)
           and c.nro_cuenta = nvl(p_nro_cuenta, c.nro_cuenta);

BEGIN
 
    
    --PDSB-464 Verifica si la modalidad origen y destino están habilitadas para el cambio
    if nvl(fug_obt_pardinamico('MOD_PER_MOD_DESTINO', 3,p_modalidad_destino, null, null), 'N') != 'S'
        or nvl(fug_obt_pardinamico('MOD_PER_MODIFICACION',3,p_modalidad_origen, null, null), 'N') != 'S' then
        raise_application_error(-20001,'Error en pra_act_modalidad, modalidad no habilitada para el cambio');
    end if;   
                           
   -- ACTUALIZACION DE DATOS
   IF v_cursor%ISOPEN THEN
      CLOSE v_cursor;
   END IF;
   OPEN v_cursor;
   LOOP
   FETCH v_cursor
   INTO v_nro_cuenta, v_cod_modalidad, v_modalidad_dest;
        EXIT WHEN v_cursor%NOTFOUND;
           
   if p_modalidad_destino != v_modalidad_dest and p_modalidad_destino is not null then
      raise_application_error(-20000, 'Debe ingresar la modalidad Destino Correcta ' || v_modalidad_dest );
	 end if; 

        update ah_cta_vistas
           set cod_modalidad = p_modalidad_destino
         where nro_cuenta = v_nro_cuenta
           and cod_modalidad = v_cod_modalidad; 
        
        update ge_cuentas
           set cod_modalidad = p_modalidad_destino
         where nro_cuenta = v_nro_cuenta
           and cod_modalidad = v_cod_modalidad;
           
        update ge_cta_clientes
           set cod_modalidad = p_modalidad_destino
         where nro_cuenta = v_nro_cuenta
           and cod_modalidad = v_cod_modalidad; 
          
         update ah_sal_mensuales
           set cod_modalidad = p_modalidad_destino
         where nro_cuenta = v_nro_cuenta
           and cod_modalidad = v_cod_modalidad;

         update ge_movimientos
           set cod_modalidad = p_modalidad_destino
         where nro_cuenta = v_nro_cuenta
           and cod_modalidad = v_cod_modalidad;
           
         -- Si existen movimientos nocturnos
         update ge_movimientos_noc
           set cod_modalidad = p_modalidad_destino
         where nro_cuenta    = v_nro_cuenta
           and cod_modalidad = v_cod_modalidad;
           
         update ah_movimientos_his
           set cod_modalidad = p_modalidad_destino
         where nro_cuenta = v_nro_cuenta
           and cod_modalidad = v_cod_modalidad;

        -- Finaliza el Circuito 
        update wf_circuitos c
           set c.estado = 'F'
         where c.cod_tip_circuito = 47
           and c.referencia = v_nro_cuenta;
           
        -- Se quita el Limite de Transacciones 
        delete from ge_cta_dat_adicionales
        where nro_cuenta =  v_nro_cuenta
          and parametro  =  'LIM_CRE_TRANSACCIONES';   
   
   END LOOP;
     
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en pra_act_modalidad ' || SQLERRM);
END;
/
