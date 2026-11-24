create or replace package body it.PAG_BAN is

  v_separador                  VARCHAR2(1) := '#';
  --v_sep_detalle                VARCHAR2(1) := '~';
  v_pedido                     VARCHAR2(1000) := ''; -- pedido al socket
  v_ok                         VARCHAR2(1);          -- indica si el socket se corto o no
  v_respuesta                  long;       -- formateado en xml
  v_nro_operacion              NUMBER(15);
  -- DATOS PARA EL ENVIO
  v_tip_operacion              NUMBER(3);
  v_usuario                    VARCHAR2(20) := 'BBVAWS';
  v_clave                      VARCHAR2(20)  := 'sistemas_0';
  -- DATOS DE RESPUESTA
  v_cod_respuesta      VARCHAR2(3);
  v_msj_respuesta      VARCHAR2(150);
  v_nom_cliente        VARCHAR2(60); -- Nombre del cliente poseedor de la tarjeta
  v_Marca              VARCHAR2(50);  -- Descripción de la marca de la tarjeta
  v_Clase              VARCHAR2(50);  -- Descripción de la clase de tarjeta
  v_Afinidad           VARCHAR2(50);  --  Descripción de la afinidad a la que pertenece la tarjeta
  v_Moneda             VARCHAR2(50);   --  Descripción de la moneda de la tarjeta
  v_Lin_credito        NUMBER(18,2) := 0; --  Línea de crédito de la tarjeta
  v_Dis_com_normal     NUMBER(18,2) := 0; --  O Saldo disponible para compras normales de la tarjeta de crédito
  v_Dis_com_cuotas     NUMBER(18,2) := 0; --  Saldo disponible para compras en cuotas de la tarjeta de crédito
  v_Dis_ava_fectivo    NUMBER(18,2) := 0; --  Saldo disponible para Avances de Efectivo de la tarjeta de crédito
  v_Deu_com_normal     NUMBER(18,2) := 0; --  Saldo de la deuda por compras normales de la tarjeta de crédito
  v_Deu_com_cuotas     NUMBER(18,2) := 0; --  Saldo de la deuda por compras en cuotas de la tarjeta de crédito
  v_Deu_total          NUMBER(18,2) := 0; -- Saldo de la deuda total de la tarjeta de crédito
  v_Deu_mora           NUMBER(18,2) := 0; -- Saldo de la deuda en mora de la tarjeta de crédito
  v_Pago_min_pendiente NUMBER(18,2) := 0; --  Monto del Pago Mínimo aún pendiente de la tarjeta de crédito
  v_Fec_ven_pag_minimo DATE;         -- Fecha del vencimiento del pago mínimo de la tarjeta de crédito,AAAAMMDD
  v_Fec_pro_cierre     DATE;         -- Fecha del próximo cierre de la tarjeta de crédito, en formato AAAAMMDD
  v_Nro_tra_infonet    NUMBER(16);   -- Nro de Transaccion de Infonet
  v_det_tarjetas       long; -- detalle de tarjetas
  v_det_movimientos    long; -- detalle de movimientos
  v_det_ciclos        VARCHAR2(4000); -- detalle de ciclos
  v_msj_extracto       VARCHAR2(2000); -- mensaje de extracto
  -- datos de extractos anteriores
  v_int_corriente     NUMBER(18,2) := 0;
  v_int_moratorio      NUMBER(18,2) := 0;
  v_gas_financieros    NUMBER(18,2) := 0;
  v_iva5               NUMBER(18,2) := 0;
  v_iva10              NUMBER(18,2) := 0;
  v_sal_pen_cuotas     NUMBER(18,2) := 0;
  --
  v_deu_cie_anterior   NUMBER(18,2) := 0;
  v_tot_deb_mes        NUMBER(18,2) := 0;
  v_tot_cre_mes        NUMBER(18,2) := 0;
  --
  -----------***  FUNCIONES Y PROCEDIMIENTOS INTERNOS ***------------
  PROCEDURE lp_reg_operacion(p_nro_tarjeta in varchar2) is
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
  BEGIN
     select s_nro_ope_bancard.nextval into v_nro_operacion from dual;
     insert into ge_log_bancard
       (nro_operacion,cod_usuario, fecha, hora, tip_operacion,
        nro_tarjeta, cod_error, msj_error, det_respuesta, cod_respuesta)
     values
       (v_nro_operacion, user, trunc(sysdate), to_char(sysdate,'HH24:MI:SS'), v_tip_operacion,
        p_nro_tarjeta, g_cod_error, g_msj_error, v_respuesta, v_cod_respuesta);
     commit;
  EXCEPTION
     when dup_val_on_index then
         null;
     when others then
         null;
  END;
  -- desglosa los datos recibidos de tarjetas con movimientos
  PROCEDURE lp_car_det_tarjetas is
     v_pos number;
  BEGIN
      v_det_tarjetas := replace(v_det_tarjetas, '~','#');
      v_pos := instr(v_det_tarjetas,'[');
      g_can_tarjetas := 0;
      if v_pos > 0 then
         g_can_tarjetas := substr(v_det_tarjetas,1,v_pos-1);
         v_det_tarjetas := substr(v_det_tarjetas,v_pos+1);
         v_det_tarjetas := replace(v_det_tarjetas,']','');
      end if;
      for i in 1..g_can_tarjetas
      loop
          t_tarjetas(i).nroTarjeta := fu_obt_dato(v_det_tarjetas,((i* 3)-2));
          t_tarjetas(i).tipoTarjeta := fu_obt_dato(v_det_tarjetas,((i* 3)-1));
          t_tarjetas(i).nombreCliente := fu_obt_dato(v_det_tarjetas,((i* 3)));
          -- OMM 13/10/2011
          if t_tarjetas(i).tipoTarjeta = 'P' then
              v_nom_cliente := t_tarjetas(i).nombreCliente ;
          end if ;
      end loop;
  END;

  -- desglosa los datos recibidos de ciclos disponibles de extractos
  PROCEDURE lp_car_det_ciclos is
     v_pos number;
  BEGIN
      v_det_ciclos := replace(v_det_ciclos, '~','#');
      v_pos := instr(v_det_ciclos,'[');
      g_can_ciclos := 0;
      if v_pos > 0 then
         g_can_ciclos := substr(v_det_ciclos,1,v_pos-1);
         v_det_ciclos := substr(v_det_ciclos,v_pos+1);
         v_det_ciclos := replace(v_det_ciclos,']','');
      end if;
      for i in 1..g_can_ciclos
      loop
          t_ciclos(i).fechaCierre := fu_obt_dato(v_det_ciclos,(i));
      end loop;
  END;

  -- desglosa los datos recibidos de los movimientos del extracto
  PROCEDURE lp_car_det_movimientos is
     v_pos number;
  BEGIN
      v_det_movimientos := replace(v_det_movimientos, '~','#');
      v_pos := instr(v_det_movimientos,'[');
      g_can_movimientos := 0;
      if v_pos > 0 then
         g_can_movimientos := substr(v_det_movimientos,1,v_pos-1);
         v_det_movimientos := substr(v_det_movimientos,v_pos+1);
         v_det_movimientos := replace(v_det_movimientos,']','');
      end if;
      for i in 1..g_can_movimientos
      loop
          t_movimientos(i).nroTarjeta      := fu_obt_dato(v_det_movimientos,((i* 7)-6));
          t_movimientos(i).tipoTransaccion := fu_obt_dato(v_det_movimientos,((i* 7)-5));
          t_movimientos(i).FechaOperacion  := fu_obt_dato(v_det_movimientos,((i* 7)-4),'F');
          t_movimientos(i).FechaProceso    := fu_obt_dato(v_det_movimientos,((i* 7)-3),'F');
          t_movimientos(i).NroCupon        := fu_obt_dato(v_det_movimientos,((i* 7)-2),'N');
          t_movimientos(i).descripcion     := fu_obt_dato(v_det_movimientos,((i* 7)-1));
          t_movimientos(i).importe         := fu_obt_dato(v_det_movimientos,((i* 7)-0),'N');
       if t_movimientos(i).importe >= 0 and t_movimientos(i).FechaOperacion is not null then
         v_tot_deb_mes := nvl(v_tot_deb_mes,0) + t_movimientos(i).importe;
       elsif t_movimientos(i).importe < 0 and t_movimientos(i).FechaOperacion is not null then
         v_tot_cre_mes := nvl(v_tot_cre_mes,0) + (t_movimientos(i).importe * -1);
       end if;
      end loop;
  END;


  -- Retorna el dato recibido por orden
  FUNCTION fu_obt_dato(P_dato IN VARCHAR2, p_nro in number, p_tipo in varchar2 default 'X')
   RETURN VARCHAR2 IS
   /** Retorna el dato segun la posicion y formateado de acuerdo al tipo */
    v_retorno long;
    v_pos number;
    v_lon number;
  BEGIN
      if p_nro = 1 then
         v_pos := 1;
      else
         v_pos := instr(p_dato,v_separador,1,(p_nro-1))+1;
         if v_pos < 2 then
            RETURN NULL;
         end if;
      end if;

      v_lon := (instr(p_dato,v_separador,1,(p_nro))) - v_pos;
      if v_lon < 0 then
        v_lon  := length(p_dato);
      end if;
      v_retorno := trim(substr(p_dato,v_pos,v_lon));
      if p_tipo = 'F' then
         -- fecha
         if v_retorno = '0' then
            v_retorno := null;
         else
            v_retorno := to_char(to_date(v_retorno,'YYYYMMDD'));
         end if;
      elsif p_tipo = 'N' then
         -- numerico
         v_retorno := replace(v_retorno,',','.');
      end if;

      RETURN v_retorno;
  EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
  END;

 /*1    METODO: pr_con_saldos PVP001
                Parametro: nro de tarjeta
                Retorno  : Varchar2 con todos los datos separados por #
 */
   PROCEDURE pr_con_saldos
      (p_nro_tarjeta in varchar2) IS
  BEGIN
    -- inicializacion de datos
    v_tip_operacion := 1;
    g_cod_error := '00';
    g_msj_error := '';
    -- Arma el mensaje a enviar
    v_pedido := v_tip_operacion || v_separador ||
                v_usuario       || v_separador ||
                v_clave         || v_separador ||
                p_nro_tarjeta || v_separador;
    -- Envia el mensaje al servidor
    v_ok := fue_env_tcp_mensajes(g_servidor,
                                 g_puerto,
                                 g_tie_espera,
                                 v_pedido,
                                 v_respuesta);
    IF v_ok != 'S' THEN
       -- Hubo problema en el envio
       g_cod_error := '998';
       g_msj_error := 'Problema con el Servicio de Socket en el Equipo '||g_servidor;
    ELSE
        -- desarma la respuesta recibida
        v_respuesta := trim(replace(replace(v_respuesta,chr(13),''),chr(10),''));
        g_cod_error := fu_obt_dato(v_respuesta,1);
        g_msj_error := fu_obt_dato(v_respuesta,2);
        v_cod_respuesta      := g_cod_error;
        v_msj_respuesta      := g_msj_error;
        v_nom_cliente        := fu_obt_dato(v_respuesta,03);
        v_Marca              := fu_obt_dato(v_respuesta,04);
        v_Clase              := fu_obt_dato(v_respuesta,05);
        v_Afinidad           := fu_obt_dato(v_respuesta,06);
        v_Moneda             := fu_obt_dato(v_respuesta,07);
        v_Lin_credito        := fu_obt_dato(v_respuesta,08,'N');
        v_Dis_com_normal     := fu_obt_dato(v_respuesta,09,'N');
        v_Dis_com_cuotas     := fu_obt_dato(v_respuesta,10,'N');
        v_Dis_ava_fectivo    := fu_obt_dato(v_respuesta,11,'N');
        v_Deu_com_normal     := fu_obt_dato(v_respuesta,12,'N');
        v_Deu_com_cuotas     := fu_obt_dato(v_respuesta,13,'N');
        v_Deu_total          := fu_obt_dato(v_respuesta,14,'N');
        v_Deu_mora           := fu_obt_dato(v_respuesta,15,'N');
        v_Pago_min_pendiente := fu_obt_dato(v_respuesta,16,'N');
        v_Fec_ven_pag_minimo := fu_obt_dato(v_respuesta,17,'F');
        v_Fec_pro_cierre     := fu_obt_dato(v_respuesta,18,'F');
        v_Nro_tra_infonet    := fu_obt_dato(v_respuesta,19,'N');

    END IF;
    -- registro la operacion en el log
    lp_reg_operacion(p_nro_tarjeta);
  EXCEPTION
     WHEN OTHERS THEN
      IF g_cod_error = '00' then
         g_cod_error := '999';
         g_msj_error := 'Problema no controlado '||g_servidor;
      END IF;
      IF sqlcode < 20000 THEN
         RAISE;
      ELSE
         lp_reg_operacion(p_nro_tarjeta);
      END IF;

  END;

 /*2    METODO: pr_con_saldos PVP002
                Parametro: nro de tarjeta
                Retorno  : Varchar2 con todos los datos separados por #
 */
   PROCEDURE pr_ext_actual
      (p_nro_tarjeta in varchar2) IS
  BEGIN
    -- inicializacion de datos
    v_tip_operacion := 2;
    g_cod_error := '00';
    g_msj_error := '';
    -- Arma el mensaje a enviar
    v_pedido := v_tip_operacion || v_separador ||
                v_usuario       || v_separador ||
                v_clave         || v_separador ||
                p_nro_tarjeta || v_separador;
    -- Envia el mensaje al servidor
    v_ok := fue_env_tcp_mensajes(g_servidor,
                                 g_puerto,
                                 g_tie_espera,
                                 v_pedido,
                                 v_respuesta);
    IF v_ok != 'S' THEN
       -- Hubo problema en el envio
       g_cod_error := '998';
       g_msj_error := 'Problema con el Servicio de Socket en el Equipo '||g_servidor;
    ELSE
        -- desarma la respuesta recibida
        v_respuesta := trim(replace(replace(v_respuesta,chr(13),''),chr(10),''));
        g_cod_error := fu_obt_dato(v_respuesta,1);
        g_msj_error := fu_obt_dato(v_respuesta,2);
        v_cod_respuesta      := g_cod_error;
        v_msj_respuesta      := g_msj_error;
        v_nom_cliente        := fu_obt_dato(v_respuesta,03);
        v_Marca              := fu_obt_dato(v_respuesta,04);
        v_Clase              := fu_obt_dato(v_respuesta,05);
        v_Afinidad           := fu_obt_dato(v_respuesta,06);
        v_Moneda             := fu_obt_dato(v_respuesta,07);
        v_Lin_credito        := fu_obt_dato(v_respuesta,08,'N');
        v_Dis_com_normal     := fu_obt_dato(v_respuesta,09,'N');
        v_Dis_com_cuotas     := fu_obt_dato(v_respuesta,10,'N');
        v_Dis_ava_fectivo    := fu_obt_dato(v_respuesta,11,'N');
        v_Deu_com_normal     := fu_obt_dato(v_respuesta,12,'N');
        v_Deu_com_cuotas     := fu_obt_dato(v_respuesta,13,'N');
        v_Deu_total          := fu_obt_dato(v_respuesta,14,'N');
        v_Deu_mora           := fu_obt_dato(v_respuesta,15,'N');
        v_Pago_min_pendiente := fu_obt_dato(v_respuesta,16,'N');
        v_Fec_ven_pag_minimo := fu_obt_dato(v_respuesta,17,'F');
        v_Fec_pro_cierre     := fu_obt_dato(v_respuesta,18,'F');
        v_det_tarjetas       := fu_obt_dato(v_respuesta,19);
        v_det_movimientos    := fu_obt_dato(v_respuesta,20);
        v_msj_extracto       := fu_obt_dato(v_respuesta,21);
        v_Nro_tra_infonet    := fu_obt_dato(v_respuesta,22,'N');
        -- cargo los detalles de tarjetas y movimientos
        lp_car_det_tarjetas;
        lp_car_det_movimientos;

    END IF;
    -- registro la operacion en el log
    lp_reg_operacion(p_nro_tarjeta);
  EXCEPTION
     WHEN OTHERS THEN
      IF g_cod_error = '00' then
         g_cod_error := '999';
         g_msj_error := 'Problema no controlado '||g_servidor;
      END IF;
      IF sqlcode < 20000 THEN
         RAISE;
      ELSE
         lp_reg_operacion(p_nro_tarjeta);
      END IF;

  END;

 /*3    METODO: pr_con_ciclos PVP003
                Parametro: nro de tarjeta
                Retorno  : Varchar2 con todos los datos separados por #
 */
   PROCEDURE pr_con_ciclos
      (p_nro_tarjeta in varchar2) IS
  BEGIN
    -- inicializacion de datos
    v_tip_operacion := 3;
    g_cod_error := '00';
    g_msj_error := '';
    -- Arma el mensaje a enviar
    v_pedido := v_tip_operacion || v_separador ||
                v_usuario       || v_separador ||
                v_clave         || v_separador ||
                trim(p_nro_tarjeta)   || v_separador;
    -- Envia el mensaje al servidor
    v_ok := fue_env_tcp_mensajes(g_servidor,
                                 g_puerto,
                                 g_tie_espera,
                                 v_pedido,
                                 v_respuesta);
    IF v_ok != 'S' THEN
       -- Hubo problema en el envio
       g_cod_error := '998';
       g_msj_error := 'Problema con el Servicio de Socket en el Equipo '||g_servidor;
    ELSE
        -- desarma la respuesta recibida
        v_respuesta := trim(replace(replace(v_respuesta,chr(13),''),chr(10),''));
        g_cod_error := fu_obt_dato(v_respuesta,1);
        g_msj_error := fu_obt_dato(v_respuesta,2);
        v_cod_respuesta      := g_cod_error;
        v_msj_respuesta      := g_msj_error;
        v_nom_cliente        := fu_obt_dato(v_respuesta,03);
        v_Marca              := fu_obt_dato(v_respuesta,04);
        v_Clase              := fu_obt_dato(v_respuesta,05);
        v_Afinidad           := fu_obt_dato(v_respuesta,06);
        v_Moneda             := fu_obt_dato(v_respuesta,07);
        v_det_ciclos         := fu_obt_dato(v_respuesta,08);
        v_Nro_tra_infonet    := fu_obt_dato(v_respuesta,09,'N');
        -- cargo los detalles de ciclos
        lp_car_det_ciclos;

    END IF;
    -- registro la operacion en el log
    lp_reg_operacion(p_nro_tarjeta);
  EXCEPTION
     WHEN OTHERS THEN
      IF g_cod_error = '00' then
         g_cod_error := '999';
         g_msj_error := 'Problema no controlado '||g_servidor;
      END IF;
      IF sqlcode < 20000 THEN
         RAISE;
      ELSE
         lp_reg_operacion(p_nro_tarjeta);
      END IF;

  END;

 /*4    METODO: pr_ext_anterior PVP004
                Parametro: nro de tarjeta

                Retorno  : Varchar2 con todos los datos separados por #
 */
   PROCEDURE pr_ext_anterior
      (p_nro_tarjeta in varchar2,
       p_fecha       in date) IS
     v_fec_enviada varchar2(8) := to_char(p_fecha,'YYYYMM');
  BEGIN
    -- veo los ciclos existentes
    pag_ban.pr_con_ciclos(p_nro_tarjeta);
    if pag_ban.fu_obt_cod_error() = '00' then
      -- busco el ciclo que corresponde
      for i in 1..pag_ban.g_can_ciclos
          loop
          if substr(pag_ban.t_ciclos(i).fechaCierre,1,6)=v_fec_enviada then
             v_fec_enviada := pag_ban.t_ciclos(i).fechaCierre;
             exit;
          end if;
      end loop;
      if length(v_fec_enviada) = 6 then
        g_cod_error := '999';
        g_msj_error := 'Extracto no disponible';
      end if;
    end if;
    if pag_ban.fu_obt_cod_error() = '00' then
        -- inicializacion de datos
        v_tip_operacion := 4;
        g_cod_error := '00';
        g_msj_error := '';
        -- Arma el mensaje a enviar
        v_pedido := v_tip_operacion || v_separador ||
                    v_usuario       || v_separador ||
                    v_clave         || v_separador ||
                    p_nro_tarjeta   || v_separador ||
                    v_fec_enviada;--to_char(p_fecha,'yyymmdd');
        -- Envia el mensaje al servidor
        v_ok := fue_env_tcp_mensajes(g_servidor,
                                     g_puerto,
                                     g_tie_espera,
                                     v_pedido,
                                     v_respuesta);
        IF v_ok != 'S' THEN
           -- Hubo problema en el envio
           g_cod_error := '998';
           g_msj_error := 'Problema con el Servicio de Socket en el Equipo '||g_servidor;
        ELSE
            -- desarma la respuesta recibida
            v_respuesta := trim(replace(replace(v_respuesta,chr(13),''),chr(10),''));
            g_cod_error := fu_obt_dato(v_respuesta,1);
            g_msj_error := fu_obt_dato(v_respuesta,2);
            v_cod_respuesta      := g_cod_error;
            v_msj_respuesta      := g_msj_error;
            v_nom_cliente        := fu_obt_dato(v_respuesta,03);
            v_Marca              := fu_obt_dato(v_respuesta,04);
            v_Clase              := fu_obt_dato(v_respuesta,05);
            v_Afinidad           := fu_obt_dato(v_respuesta,06);
            v_Moneda             := fu_obt_dato(v_respuesta,07);
            v_Lin_credito        := fu_obt_dato(v_respuesta,08,'N');
            v_Dis_com_normal     := fu_obt_dato(v_respuesta,09,'N');
            v_deu_cie_anterior   := fu_obt_dato(v_respuesta,10,'N');
            v_int_corriente      := fu_obt_dato(v_respuesta,11,'N');
            v_int_moratorio      := fu_obt_dato(v_respuesta,12,'N');
            v_gas_financieros    := fu_obt_dato(v_respuesta,13,'N');
            v_iva5               := fu_obt_dato(v_respuesta,14,'N');
            v_iva10              := fu_obt_dato(v_respuesta,15,'N');
            v_sal_pen_cuotas     := fu_obt_dato(v_respuesta,16,'N');
            v_Deu_total          := fu_obt_dato(v_respuesta,17,'N');
            v_Pago_min_pendiente := fu_obt_dato(v_respuesta,18,'N');
            v_Fec_ven_pag_minimo := fu_obt_dato(v_respuesta,19,'F');
            v_det_tarjetas       := fu_obt_dato(v_respuesta,20);
            v_det_movimientos    := fu_obt_dato(v_respuesta,21);
            v_Nro_tra_infonet    := fu_obt_dato(v_respuesta,22,'N');
            -- cargo los detalles de tarjetas y movimientos
            lp_car_det_tarjetas;
            lp_car_det_movimientos;

        END IF;
    end if;
    -- registro la operacion en el log
    lp_reg_operacion(p_nro_tarjeta);
  EXCEPTION
     WHEN OTHERS THEN
      IF g_cod_error = '00' then
         g_cod_error := '999';
         g_msj_error := 'Problema no controlado '||g_servidor;
      END IF;
      IF sqlcode < 20000 THEN
         RAISE;
      ELSE
         lp_reg_operacion(p_nro_tarjeta);
      END IF;

  END;
  
 /*2    METODO: fu_mov_ext_actual PVP002
                Parametro: nro de tarjeta, orden de movimiento, cantidad de detalles
                p_detalle  : detalle de los n movimientos segun 
                             p_orden  - A primeros movimientos, sino ultimos movimientos
                                     
                            Valores guardados
                            ------------------
                            tipo_transacción(1)
                            importe(16)
                            descripción(20)
                            fecha operación(10)
 */
  FUNCTION fu_mov_ext_actual(p_nro_tarjeta  in varchar2,
                             p_orden        in varchar2,
                             p_can_detalles in out number) 
    RETURN LONG IS
    v_movimientos     long;
    v_can_movimientos number;
    v_pos             number;
    v_detalle         long;
    tr_movimientos t_cur_movimientos;
    tmp_mov t_cur_movimientos;
  BEGIN
    -- inicializacion de datos
    v_tip_operacion := 2;
    g_cod_error := '00';
    g_msj_error := '';
    -- Arma el mensaje a enviar
    v_pedido := v_tip_operacion || v_separador ||
                v_usuario       || v_separador ||
                v_clave         || v_separador ||
                p_nro_tarjeta || v_separador;
    -- Envia el mensaje al servidor
    v_ok := fue_env_tcp_mensajes(g_servidor,
                                 g_puerto,
                                 g_tie_espera,
                                 v_pedido,
                                 v_respuesta);
    IF v_ok != 'S' THEN
      -- Hubo problema en el envio
      g_cod_error := '998';
      g_msj_error := 'Problema con el Servicio de Socket en el Equipo '||g_servidor;
    ELSE
      -- desarma la respuesta recibida
      v_respuesta       := trim(replace(replace(v_respuesta,chr(13),''),chr(10),''));
      g_cod_error       := fu_obt_dato(v_respuesta,1);
      g_msj_error       := fu_obt_dato(v_respuesta,2);
      v_cod_respuesta   := g_cod_error;
      v_msj_respuesta   := g_msj_error;        
      v_movimientos     := fu_obt_dato(v_respuesta,20);    
      v_movimientos     := replace(v_movimientos, '~','#');
      v_pos             := instr(v_movimientos,'[');
      v_can_movimientos := 0;
      v_detalle         := '';
      -- consulta si tiene movimientos
      IF v_pos > 0 THEN
        v_can_movimientos := substr(v_movimientos,1,v_pos-1);
        v_movimientos := substr(v_movimientos,v_pos+1);
        v_movimientos := replace(v_movimientos,']','');
      END IF;
      -- cargamos los movimientos
      FOR i in 1..v_can_movimientos LOOP
         tr_movimientos(i).nroTarjeta      := fu_obt_dato(v_movimientos,((i* 7)-6));
         tr_movimientos(i).tipoTransaccion := fu_obt_dato(v_movimientos,((i* 7)-5));
         tr_movimientos(i).FechaOperacion  := fu_obt_dato(v_movimientos,((i* 7)-4),'F');
         tr_movimientos(i).FechaProceso    := fu_obt_dato(v_movimientos,((i* 7)-3),'F');
         tr_movimientos(i).NroCupon        := fu_obt_dato(v_movimientos,((i* 7)-2),'N');
         tr_movimientos(i).descripcion     := fu_obt_dato(v_movimientos,((i* 7)-1));
         tr_movimientos(i).importe         := fu_obt_dato(v_movimientos,((i* 7)-0),'N');
      END LOOP;
      -- se ordena segun p_orden, A-Ascendete
      FOR i in 1..v_can_movimientos-1 LOOP
         FOR j in i+1..v_can_movimientos LOOP
            IF ((tr_movimientos(i).FechaOperacion > tr_movimientos(j).FechaOperacion and p_orden = 'A') or 
                (tr_movimientos(i).FechaOperacion < tr_movimientos(j).FechaOperacion and p_orden = 'D'))THEN
               tmp_mov(0) := tr_movimientos(i);
               tr_movimientos(i) := tr_movimientos(j);
               tr_movimientos(j) := tmp_mov(0);
            END IF;
         END LOOP;
      END LOOP;
      -- se obtienen los movimientos segun p_can_detalles
      IF p_can_detalles < v_can_movimientos THEN
         v_can_movimientos := p_can_detalles;
      END IF;
      p_can_detalles := 0;
      FOR i in 1..v_can_movimientos LOOP
         v_detalle := v_detalle||rpad(tr_movimientos(i).tipoTransaccion, 1)
                               ||lpad(tr_movimientos(i).importe,16,' ')
                               ||rpad(substr(tr_movimientos(i).descripcion, 1, 20), 20) -- descripción(20)
                               ||rpad(tr_movimientos(i).FechaOperacion, 10); -- fecha operación(10)

         p_can_detalles := p_can_detalles + 1;
      END LOOP;
    END IF;
    -- registro la operacion en el log
    lp_reg_operacion(p_nro_tarjeta);
    RETURN v_detalle;
  EXCEPTION
     WHEN OTHERS THEN
      IF g_cod_error = '00' then
         g_cod_error := '999';
         g_msj_error := 'Problema no controlado '||g_servidor;
      END IF;
      IF sqlcode < 20000 THEN
         RAISE;
      ELSE
         lp_reg_operacion(p_nro_tarjeta);
      END IF;
      RETURN '';
  END;
  /* Obtiene el codigo de error del registro del paquete. */
  FUNCTION fu_obt_cod_error
   RETURN VARCHAR2  IS
  BEGIN
      return g_cod_error;
  END;
  /* Obtener el lugar en el que quedo cargado el registro del paquete. */
  FUNCTION fu_obt_lugar
   RETURN VARCHAR2  IS
  BEGIN
      return g_lugar;
  END;
  /* Obtiene el mensaje de error contenido en el registro del paquete. */
  FUNCTION fu_obt_msj_error
   RETURN VARCHAR2  IS
  BEGIN
      return g_msj_error;
  END;
  -- Nombre del poseedor de la tarjeta
  FUNCTION fu_nom_cliente
    RETURN  VARCHAR2 IS
  BEGIN
    RETURN v_nom_cliente;
  END;
  -- Descripción de la marca de la tarjeta
  FUNCTION fu_Marca
    RETURN  VARCHAR2 IS
  BEGIN
    RETURN v_Marca;
  END;
  -- Descripción de la clase de tarjeta
  FUNCTION fu_Clase
    RETURN  VARCHAR2 IS
  BEGIN
    RETURN v_Clase;
  END;
  --  Descripción de la afinidad a la que pertenece la tarjeta
  FUNCTION fu_Afinidad
    RETURN  VARCHAR2 IS
  BEGIN
    RETURN v_Afinidad;
  END;
  --  Descripción de la moneda de la tarjeta
  FUNCTION fu_Moneda
    RETURN  VARCHAR2 IS
  BEGIN
    RETURN v_Moneda;
  END;
  --  Línea de crédito de la tarjeta
  FUNCTION fu_Lin_credito
    RETURN  NUMBER IS
  BEGIN
    RETURN v_Lin_credito;
  END;
  --  Saldo disponible para compras normales de la tarjeta de crédito
  FUNCTION fu_Dis_com_normal
    RETURN  NUMBER IS
  BEGIN
    RETURN v_Dis_com_normal;
  END;
  --  Saldo disponible para compras en cuotas de la tarjeta de crédito
  FUNCTION fu_Dis_com_cuotas
    RETURN  NUMBER IS
  BEGIN
    RETURN v_Dis_com_cuotas;
  END;
   --  Saldo disponible para Avances de Efectivo de la tarjeta de crédito
  FUNCTION fu_Dis_ava_fectivo
    RETURN  NUMBER IS
  BEGIN
    RETURN v_Dis_ava_fectivo;
  END;
  --  Saldo de la deuda por compras normales de la tarjeta de crédito
  FUNCTION fu_Deu_com_normal
    RETURN  NUMBER IS
  BEGIN
    RETURN v_Deu_com_normal;
  END;
  --  Saldo de la deuda por compras en cuotas de la tarjeta de crédito
  FUNCTION fu_Deu_com_cuotas
    RETURN  NUMBER IS
  BEGIN
    RETURN v_Deu_com_cuotas;
  END;
  -- Saldo de la deuda total de la tarjeta de crédito
  FUNCTION fu_Deu_total
    RETURN  NUMBER IS
  BEGIN
    RETURN v_Deu_total;
  END;
  -- Saldo de la deuda en mora de la tarjeta de crédito
  FUNCTION fu_Deu_mora
    RETURN  NUMBER IS
  BEGIN
    RETURN v_Deu_mora;
  END;
  --  Monto del Pago Mínimo aún pendiente de la tarjeta de crédito
  FUNCTION fu_Pago_min_pendiente
    RETURN  NUMBER IS
  BEGIN
    RETURN v_Pago_min_pendiente;
  END;
  --  Deuda anterior de la tarjeta
  FUNCTION fu_deu_cie_anterior
    RETURN  NUMBER IS
  BEGIN
    RETURN v_deu_cie_anterior;
  END;
  --  total de debitos del mes
  FUNCTION fu_tot_deb_mes
    RETURN  NUMBER IS
  BEGIN
    RETURN v_tot_deb_mes;
  END;
  --  total de creditos del mes
  FUNCTION fu_tot_cre_mes
    RETURN  NUMBER IS
  BEGIN
    RETURN v_tot_cre_mes;
  END;
  -- Fecha del vencimiento del pago mínimo de la tarjeta de crédito,AAAAMMDD
  FUNCTION fu_Fec_ven_pag_minimo
    RETURN  DATE IS
  BEGIN
    RETURN v_Fec_ven_pag_minimo;
  END;
  -- Fecha del próximo cierre de la tarjeta de crédito, en formato AAAAMMDD
  FUNCTION fu_Fec_pro_cierre
    RETURN  DATE IS
  BEGIN
    RETURN v_Fec_pro_cierre;
  END;
  -- Nro de Transaccion de Infonet
  FUNCTION fu_Nro_tra_infonet
    RETURN  NUMBER IS
  BEGIN
    RETURN v_Nro_tra_infonet;
  END;

end PAG_BAN;
/

