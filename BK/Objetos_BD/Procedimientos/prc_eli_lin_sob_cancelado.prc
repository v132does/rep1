create or replace procedure it.PRC_ELI_LIN_SOB_CANCELADO is
  /* Procedimiento que elimina las líneas de Sobregiro en caso de que se encuentren canceladas y no hayan sido eliminadas desde el programa de cancelación*/

  --Variables--
  v_nro_secuencia cc_lin_sobregiros.nro_secuencia%type;
  v_mensaje varchar2(500) := null;

  --Cursor de Lineas Canceladas--
  cursor c_lin_canceladas is
    select cli.tipo, cli.nro_linea, cli.nro_secuencia, cli.rowid fila
      from cc_lin_sobregiros cli
     where cli.estado = 'C'
       and cli.nro_sec_padre is null
       and cli.cod_persona is not null;

BEGIN
   v_mensaje := '1-Inhabilita trigger TB_CC_LIN_SOBREGIROS';
   execute immediate 'alter trigger TB_CC_LIN_SOBREGIROS disable';
   for det in c_lin_canceladas loop
       v_nro_secuencia := det.nro_secuencia;

       v_mensaje := '2-Inserta Histórico CC_LIN_SOBREGIROS';
       --Insertar en el Historico cc_lin_sobregiros--
       INSERT INTO CC_LIN_SOBREGIROS_HIS(COD_USU_AUTORIZA,NRO_CUENTA,FEC_VENCIMIENTO,
                   COD_TASA,VAL_TAS_INTERES,DIA_TASA,TAS_PREFERENCIAL,DIA_SIN_COSTO,
                   NRO_LINEA,FEC_INICIO,NRO_SECUENCIA,MONTO,TIPO,COD_PERSONA,COD_MONEDA,ESTADO,
                   NRO_SEC_PADRE,OBSERVACION,NIV_APROBACION,CAN_AUTOMATICA, COD_RUB_ECONOMICO, COD_CAMPANA)
           (SELECT COD_USU_AUTORIZA,NRO_CUENTA,FEC_VENCIMIENTO,
                   COD_TASA,VAL_TAS_INTERES,DIA_TASA,TAS_PREFERENCIAL,DIA_SIN_COSTO,
                   NRO_LINEA,FEC_INICIO,NRO_SECUENCIA,MONTO,TIPO,COD_PERSONA,COD_MONEDA,ESTADO,
                   NRO_SEC_PADRE,OBSERVACION,NIV_APROBACION,'N', COD_RUB_ECONOMICO, COD_CAMPANA
              FROM CC_LIN_SOBREGIROS
             WHERE NRO_SECUENCIA = v_nro_secuencia
                OR NRO_SEC_PADRE = v_nro_secuencia);

        v_mensaje := '3-Inserta Histórico CC_LIN_SOB_GARANTIAS';
       --Insertar en el Historico cc_lin_sob_garantias--
       INSERT INTO CC_LIN_SOB_GARANTIAS_HIS(MTO_APLICADO,NRO_GARANTIA,NRO_SECUENCIA,COD_GARANTIA)
       (SELECT MTO_APLICADO,NRO_GARANTIA,NRO_SECUENCIA,COD_GARANTIA
          FROM CC_LIN_SOB_GARANTIAS
         WHERE NRO_SECUENCIA = v_nro_secuencia);

       --Eliminar Lineas Canceladas--
       v_mensaje := '4-Eliminar cc_lin_sob_garantias';
       DELETE FROM CC_LIN_SOB_GARANTIAS C
       WHERE C.NRO_SECUENCIA = v_nro_secuencia;

       v_mensaje := '5-Eliminar cc_lin_sobregiros-Hijos';
       DELETE FROM CC_LIN_SOBREGIROS C
       WHERE C.NRO_SEC_PADRE = v_nro_secuencia;

       v_mensaje := '6-Eliminar cc_lin_sobregiros-Padre';
       DELETE FROM CC_LIN_SOBREGIROS C
       WHERE C.NRO_SECUENCIA = v_nro_secuencia;
    end loop;

   v_mensaje := '7-Habilita trigger TB_CC_LIN_SOBREGIROS';
   execute immediate 'alter trigger TB_CC_LIN_SOBREGIROS enable';

EXCEPTION
  when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000, 'Error al Eliminar Lin.Sob.Canceladas: '||v_mensaje||'-'||v_nro_secuencia||'-'||sqlerrm);
      end if;
end PRC_ELI_LIN_SOB_CANCELADO;
/

