CREATE OR REPLACE PROCEDURE IT.PRB_SMG_ACT_CB_ASIENTOS IS
  v_nro_referencia    NUMBER(07);
  v_contador    NUMBER(07);
  v_msj varchar2(250);
  v_nro_asiento number(9);
  v_nro_oficina number(3);
  v_fecha date;
  v_asiento_ini number(2);
  v_cantidad  number(10);
  v_result number:=0;
  v_fec_contable varchar2(10):=to_char(pae_cnf.fu_obt_fec_actual(2),'dd/mm/yy');
 ---cursor
 CURSOR CONTA IS
    SELECT s.itsuc, s.itcta, s.itmonto, s.itmontome, s.ittipo, s.itref, r.cod_rubro
    from simgia_debcrecont s, cb_rubros r
    where s.itsuc <> 0
    and s.itcta is not null
    and r.cod_rub_externo = to_char(s.itcta)
    and s.itmonto > 0
    order by s.itsuc asc;

BEGIN
  v_contador := 0;
  v_nro_oficina := 0;
  v_fecha := pag_cal.fu_obt_fec_actual(2);
  v_asiento_ini := 0;

  -- Verificar si existen asientos migrados
  select count(*) into v_result from simgia_debcrecont t where itsuc = 0 and itcta = 0 and itref = to_number(nvl(to_char(pae_cnf.fu_obt_fec_actual(2),'ddmmyy'),0));
  if(v_result=0) then
    --error, no son datos del dia actual
    RAISE_APPLICATION_ERROR(-20000,'Los datos de DEBCRECONT no corresponden al día ' ||  v_fec_contable);
  end if;

  -- Verificar si existen asientos migrados
  BEGIN
     select nvl(count(*),0) into v_cantidad
       from cb_asientos a
      where a.cod_usuario='MIGRA';
     if v_cantidad > 0 then
        --- Eliminar asientos que ya existen
        delete cb_asientos_det d
         where exists(select 1 from cb_asientos a
         where a.fecha=d.fecha
           and a.cod_oficina=d.cod_oficina
           and a.nro_asiento=d.nro_asiento
           and a.cod_usuario='MIGRA');
        delete cb_asientos a
         where a.cod_usuario='MIGRA';
        --Obtener el ultimo numero de asiento y actualizar el parametro
        select max(nro_asiento)
          into v_nro_asiento
          from cb_asientos;
        if v_nro_asiento is null then
          select max(nro_asiento)
            into v_nro_asiento
            from cb_asientos_his;
        end if;
        prg_act_par_dinamico('SIG_NRO_ASIENTO',NULL,NULL,NULL,NULL,(v_nro_asiento + 1));
     end if;
  END;
  -- Re-migrar
  FOR i in CONTA loop

    BEGIN

      IF v_contador = 0 THEN
          v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
      END IF;
      IF v_nro_oficina <>  i.itsuc THEN
         v_contador := 0;
         if v_asiento_ini=0 then
             v_asiento_ini := v_asiento_ini + 1;
          else
             v_nro_asiento := v_nro_asiento + 1;
          end if;
      end if;

      v_nro_oficina := i.itsuc;
      v_contador := nvl(v_contador,0) + 1;

       SELECT  c.cod_oficina INTO v_nro_referencia
       FROM cb_asientos c
       WHERE cod_oficina = i.itsuc
       AND c.nro_asiento = v_nro_asiento
       AND c.fecha = v_fecha;

       UPDATE cb_asientos cba
       SET cba.tot_control = NVL(tot_control,0) + nvl(i.itmonto,0)
       WHERE cod_oficina= v_nro_referencia
       AND cba.nro_asiento = v_nro_asiento
       AND cba.fecha = v_fecha;

       INSERT INTO cb_asientos_det
       (FECHA,COD_OFICINA,NRO_ASIENTO,NRO_LINEA,COD_RUBRO,TIP_MOVIMIENTO,MTO_MON_RUBRO,MTO_MON_LOCAL,DESCRIPCION,REFERENCIA)
       VALUES(v_fecha,nvl(i.itsuc,0),nvl(v_nro_asiento,0),nvl(v_contador,0),
       nvl(i.cod_rubro,'0'),
       i.ittipo,nvl(i.itmontome,0),nvl(i.itmonto,0),substr(i.itref,1,60),substr(to_char(nvl(i.itcta,0)),1,11));

   ------------------------------------------------------------------------------------------------------------------

    EXCEPTION
     WHEN NO_DATA_FOUND THEN
         IF nvl(i.itmonto,0) <> 0  THEN

            INSERT INTO cb_asientos(FECHA,COD_OFICINA,NRO_ASIENTO,COD_MODULO,COD_MODALIDAD,TOT_CONTROL,COD_USUARIO,OFI_INTEGRADA,FEC_VALOR)
            VALUES (v_fecha,nvl(i.itsuc,0),nvl(v_nro_asiento,0),2,21,nvl(i.itmonto,0),'MIGRA','N',v_fecha);

            prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento);

            if nvl(i.itmonto,0) <> 0 then
                   INSERT INTO cb_asientos_det
                   (FECHA,COD_OFICINA,NRO_ASIENTO,NRO_LINEA,COD_RUBRO,TIP_MOVIMIENTO,MTO_MON_RUBRO,MTO_MON_LOCAL,DESCRIPCION,REFERENCIA)
                   VALUES(v_fecha,nvl(i.itsuc,0),nvl(v_nro_asiento,0),nvl(v_contador,0),
                   nvl(i.cod_rubro,'0'),
                   i.ittipo,nvl(i.itmontome,0),nvl(i.itmonto,0),substr(i.itref,1,60),substr(to_char(nvl(i.itcta,0)),1,11));--substr(i.itref,1,60)
            end if;

         END IF;

    END;

  END LOOP;

EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PRB_SMG_ACT_CB_ASIENTOS:'||sqlerrm);
END   PRB_SMG_ACT_CB_ASIENTOS  ;
/

