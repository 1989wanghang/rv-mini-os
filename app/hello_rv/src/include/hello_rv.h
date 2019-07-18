/*
 * Copyright 2018 Rockchip Electronics Co., Ltd. All Rights Reserved.
 * author: hertz.wang, wangh@rock-chips.com
 *
 * SPDX-License-Identifier: Apache-2.0
 */


#if ENABLE_SMILE
int print_smile();
#else
inline int print_smile() {
	return -1;
}
#endif
