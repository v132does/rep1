CREATE OR REPLACE FUNCTION IT.FUP_OBT_DAT_NOMINAS(p_nro_cuenta ge_movimientos.nro_cuenta%type,
                                               p_monto      ge_movimientos.monto%type,
                                               p_fecha      date,
                                               p_entidad    ge_par_entes.cod_ente%type,
                                               p_consulta   IN NUMBER DEFAULT 1)
 return varchar2
 is
v_retorno varchar(200);
/* función que retorna datos del pago de nómina */
BEGIN
   if p_consulta = 1 then
      -- Tipo de Procesamiento de Nómina --
      Select decode(val_parametro, 'O', 'ON-LINE', 'R', 'REQ', 'BATCH')
        into v_retorno
        from ge_par_entes
       where cod_ente = p_entidad
         and parametro = 'TIP_PRO_SUELDO';
   elsif p_consulta = 2 then
      -- Usuario que Registro el Pago --
      Select max(cod_usuario)
        into v_retorno
        from (select mo.cod_usuario
                from ah_movimientos_his mo
               where mo.nro_cuenta = p_nro_cuenta
                 and mo.fec_valor = p_fecha
                 and mo.monto = p_monto
                 and mo.cod_tra_padre in (303, 333, 3303)
              union all
              select mo.cod_usuario
                from cc_movimientos_his mo
               where mo.nro_cuenta = p_nro_cuenta
                 and mo.fec_valor = p_fecha
                 and mo.monto = p_monto
                 and mo.cod_tra_padre in (303, 333, 3303));
      if trim(v_retorno) is null then
        select m.usu_insercion
          into v_retorno
          from bw_movimientos m
         where m.nro_cuenta = p_nro_cuenta
           and trunc(m.fec_insercion) = p_fecha
           and cod_tip_mensaje = '070'
           and rownum < 2
         order by m.fec_insercion desc;
      end if;
   elsif p_consulta = 3 then
      -- Transaccion del Pago --
      Select max(cod_tra_padre)
        into v_retorno
        from (select mo.cod_tra_padre
                from ah_movimientos_his mo
               where mo.nro_cuenta = p_nro_cuenta
                 and mo.fec_valor = p_fecha
                 and mo.MONTO = p_monto
                 and mo.cod_tra_padre in (303, 333, 3303)
              union all
              select mo.cod_tra_padre
                from cc_movimientos_his mo
               where mo.nro_cuenta = p_nro_cuenta
                 and mo.fec_valor = p_fecha
                 and mo.monto = p_monto
                 and mo.cod_tra_padre in (303, 333, 3303));
      if trim(v_retorno) is null then
        select mo.cod_tra_padre
          into v_retorno
          from ge_movimientos mo
         where mo.nro_cuenta = p_nro_cuenta
           and mo.fecha = p_fecha
           and mo.monto = p_monto
           and mo.cod_tra_padre in (303, 333, 3303);
        end if;
   elsif p_consulta = 4 then
       -- Nro. de operación --
          Select max(nro_documento)
            into v_retorno
            from (select mo.nro_documento
                    from ah_movimientos_his mo
                   where mo.nro_cuenta = p_nro_cuenta
                     and mo.fec_valor = p_fecha
                     and mo.monto = p_monto
                     and mo.cod_tra_padre in (303, 333, 3303)
                  union all
                  select mo.nro_documento
                    from cc_movimientos_his mo
                   where mo.nro_cuenta = p_nro_cuenta
                     and mo.fec_valor = p_fecha
                     and mo.monto = p_monto
                     and mo.cod_tra_padre in (303, 333, 3303));
            if trim(v_retorno) is null then
                select mo.nro_documento
                  into v_retorno
                  from ge_movimientos mo
                 where mo.nro_cuenta = p_nro_cuenta
                   and mo.fecha = p_fecha
                   and mo.monto = p_monto
                   and mo.cod_tra_padre in (303, 333, 3303);
            end if;
   end if;
   return v_retorno ;
exception
  when others then
     v_retorno := 'NO DEVUELVE DATO';
     return v_retorno ;
END;
/

